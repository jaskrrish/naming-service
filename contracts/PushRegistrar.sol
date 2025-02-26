// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IPNS} from  "./interfaces/IPushRegistry.sol";
import "./interfaces/IBaseRegistrar.sol";
import "./utils/Errors.sol";

contract BaseRegistrar is ERC721, ERC721Enumerable, IBaseRegistrar, Ownable {
    // A map of expiry times
    mapping(uint256 => uint256) expiries;
    
    // The PNS registry
    IPNS public immutable registry;
    
    // The namehash of the TLD this registrar owns (eg, .push)
    bytes32 public immutable baseNode;
    
    // A map of addresses that are authorised to register and renew names.
    mapping(address => bool) public controllers;

    uint256 public constant GRACE_PERIOD = 90 days;

    bytes4 private constant INTERFACE_META_ID = bytes4(keccak256("supportsInterface(bytes4)"));
    bytes4 private constant ERC721_ID = bytes4(
        keccak256("balanceOf(address)") ^
        keccak256("ownerOf(uint256)") ^
        keccak256("approve(address,uint256)") ^
        keccak256("getApproved(uint256)") ^
        keccak256("setApprovalForAll(address,bool)") ^
        keccak256("isApprovedForAll(address,address)") ^
        keccak256("transferFrom(address,address,uint256)") ^
        keccak256("safeTransferFrom(address,address,uint256)") ^
        keccak256("safeTransferFrom(address,address,uint256,bytes)")
    );
    bytes4 private constant RECLAIM_ID = bytes4(keccak256("reclaim(uint256,address)"));

    constructor(IPNS _registry, bytes32 _baseNode) 
        ERC721("Push Names", "PUSH") 
        Ownable()
    {
        registry = _registry;
        baseNode = _baseNode;
    }

    modifier live {
        if (registry.owner(baseNode) != address(this)) revert ContractNotLive();
        _;
    }

    modifier onlyController {
        if (!controllers[msg.sender]) revert OnlyControllerAllowed();
        _;
    }

    /**
     * @dev Gets the owner of the specified token ID. Names become unowned
     *      when their registration expires.
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view override(ERC721, IERC721) returns (address) {
    if(expiries[tokenId] <= block.timestamp) revert RegistrationExpired();
    return super.ownerOf(tokenId);
}

    // Authorises a controller, who can register and renew domains.
    function addController(address controller) external override onlyOwner {
        controllers[controller] = true;
        emit ControllerAdded(controller);
    }

    // Revoke controller permission for an address.
    function removeController(address controller) external override onlyOwner {
        controllers[controller] = false;
        emit ControllerRemoved(controller);
    }

    // Set the resolver for the TLD this registrar manages.
    function setResolver(address resolver) external override onlyOwner {
        registry.setResolver(baseNode, resolver);
    }

    // Returns the expiration timestamp of the specified id.
    function nameExpires(uint256 id) external view override returns(uint256) {
        return expiries[id];
    }

    // Returns true if the specified name is available for registration.
    function available(uint256 id) public view override returns(bool) {
        // Not available if it's registered here or in its grace period.
        return expiries[id] + GRACE_PERIOD < block.timestamp;
    }

    /**
     * @dev Register a name.
     * @param id The token ID (keccak256 of the label).
     * @param owner The address that should own the registration.
     * @param duration Duration in seconds for the registration.
     */
    function register(uint256 id, address owner, uint256 duration) 
        external
        override 
        returns(uint256)
    {
        return _register(id, owner, duration, true);
    }

    /**
     * @dev Register a name, without modifying the registry.
     * @param id The token ID (keccak256 of the label).
     * @param owner The address that should own the registration.
     * @param duration Duration in seconds for the registration.
     */
    function registerOnly(uint256 id, address owner, uint256 duration) 
        external
        returns(uint256)
    {
        return _register(id, owner, duration, false);
    }

    function _register(uint256 id, address owner, uint256 duration, bool updateRegistry) 
        internal
        live
        onlyController
        returns(uint256)
    {
        if(!available(id)) revert InvalidTokenId();
        if(!(block.timestamp + duration + GRACE_PERIOD > block.timestamp + GRACE_PERIOD)) revert InvalidDuration(duration);

        expiries[id] = block.timestamp + duration;
        if(_exists(id)) {
            // Name was previously owned, and expired
            _burn(id);
        }
        _mint(owner, id);
        if(updateRegistry) {
            registry.setSubnodeOwner(baseNode, bytes32(id), owner);
        }

        emit NameRegistered(id, owner, block.timestamp + duration);

        return block.timestamp + duration;
    }

    function renew(uint256 id, uint256 duration) 
        external
        override
        live
        onlyController
        returns(uint256)
    {
        if(!(expiries[id] + GRACE_PERIOD >= block.timestamp)) revert InvalidTokenId(); // Name must be registered here or in grace period
        if(!(expiries[id] + duration + GRACE_PERIOD > duration + GRACE_PERIOD)) revert InvalidDuration(duration); // Prevent future overflow

        expiries[id] += duration;
        emit NameRenewed(id, expiries[id]);
        return expiries[id];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @dev Reclaim ownership of a name in PNS, if you own it in the registrar.
     */
    function reclaim(uint256 id, address owner) external live {
        if (!_isApprovedOrOwner(msg.sender, id)) revert InvalidAddress(owner);
        registry.setSubnodeOwner(baseNode, bytes32(id), owner);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return 
            interfaceId == INTERFACE_META_ID ||
            interfaceId == ERC721_ID ||
            interfaceId == RECLAIM_ID ||
            super.supportsInterface(interfaceId);
    }
}