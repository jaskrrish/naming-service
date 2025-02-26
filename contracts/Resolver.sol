// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Multicallable} from "@ensdomains/ens-contracts/contracts/resolvers/Multicallable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./interfaces/IResolver.sol";
import "./interfaces/IPushRegistry.sol";
import "./utils/Errors.sol";

contract PublicResolver is IResolver, Multicallable {
    IPNS immutable registry;
    address immutable trustedController;

    mapping(bytes32 => address) addresses;
    mapping(bytes32 => mapping(string => string)) texts;
    mapping(bytes32 => bytes) contenthashes;
    mapping(bytes32 => string) public names;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(address => mapping(bytes32 => mapping(address => bool))) private _tokenApprovals;

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Approved(address owner, bytes32 indexed node, address indexed delegate, bool indexed approved);
    
    constructor(IPNS _registry, address _trustedController) {
        if (address(_registry) == address(0)) revert InvalidAddress(address(0));
        if (_trustedController == address(0)) revert InvalidAddress(address(0));

        registry = _registry;
        trustedController = _trustedController;
    }

    function isAuthorised(bytes32 node) internal view returns (bool) {
        if (msg.sender == trustedController) {
            return true;
        }
        address owner = registry.owner(node);
        return owner == msg.sender || isApprovedForAll(owner, msg.sender) || isApprovedFor(owner, node, msg.sender);
    }

    modifier authorised(bytes32 node) {
        if (!isAuthorised(node)) revert Unauthorized(msg.sender, node);
        _;
    }

    // Approval functions
    function setApprovalForAll(address operator, bool approved) external {
        if (msg.sender == operator) revert SelfApprovalNotAllowed();
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function approve(bytes32 node, address delegate, bool approved) external {
        if (msg.sender != delegate) revert InvalidAddress(delegate);
        _tokenApprovals[msg.sender][node][delegate] = approved;
        emit Approved(msg.sender, node, delegate, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function isApprovedFor(address owner, bytes32 node, address delegate) public view returns (bool) {
        return _tokenApprovals[owner][node][delegate];
    }

    // Record management
    function setAddr(bytes32 node, address addr) external authorised(node) {
        addresses[node] = addr;
        emit AddrChanged(node, addr);
    }

    function setText(bytes32 node, string calldata key, string calldata value) external authorised(node) {
        texts[node][key] = value;
        emit TextChanged(node, key, value);
    }

    function setContenthash(bytes32 node, bytes calldata hash) external authorised(node) {
        contenthashes[node] = hash;
        emit ContenthashChanged(node, hash);
    }

    function setName(bytes32 node, string calldata name) external authorised(node) {
        names[node] = name;
        emit NameChanged(node, name);
    }

    // Getters
    function addr(bytes32 node) public view returns (address) {
        return addresses[node];
    }

    function text(bytes32 node, string calldata key) public view returns (string memory) {
        return texts[node][key];
    }

    function contenthash(bytes32 node) public view returns (bytes memory) {
        return contenthashes[node];
    }

    function name(bytes32 node) public view returns (string memory) {
        return names[node];
    }

    function supportsInterface(bytes4 interfaceID) public view virtual override(Multicallable, IERC165) returns (bool) {
        return interfaceID == type(IResolver).interfaceId || super.supportsInterface(interfaceID);
    }
}
