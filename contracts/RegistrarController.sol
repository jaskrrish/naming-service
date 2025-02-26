// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPriceOracle.sol";
import "./PushRegistrar.sol";
import "./utils/Errors.sol";

contract PushRegistrarController is Ownable {
    uint256 public constant MIN_REGISTRATION_DURATION = 28 days;
    
    BaseRegistrar immutable base;
    IPriceOracle public immutable prices;
    uint256 public immutable minCommitmentAge;
    uint256 public immutable maxCommitmentAge;
    
    mapping(bytes32 => uint256) public commitments;

    event NameRegistered(
        string name,
        bytes32 indexed label,
        address indexed owner,
        uint256 cost,
        uint256 expires
    );
    event NameRenewed(
        string name,
        bytes32 indexed label,
        uint256 cost,
        uint256 expires
    );

    constructor(
        BaseRegistrar _base,
        IPriceOracle _prices,
        uint256 _minCommitmentAge,
        uint256 _maxCommitmentAge
    ) {
        if (_maxCommitmentAge <= _minCommitmentAge) revert InvalidDuration(_maxCommitmentAge);
        if (address(_base) == address(0)) revert InvalidAddress(address(0));
        if (address(_prices) == address(0)) revert InvalidAddress(address(0));
        
        base = _base;
        prices = _prices;
        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
    }

    function rentPrice(
        string memory name,
        uint256 duration
    ) public view returns (uint256) {
        return prices.price(name, duration);
    }

    function valid(string memory name) public pure returns (bool) {
        return bytes(name).length >= 3;
    }

    function available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && base.available(uint256(label));
    }

    function makeCommitment(
        string memory name,
        address owner,
        uint256 duration,
        bytes32 secret,
        address resolver,
        bytes[] calldata data
    ) public pure returns (bytes32) {
        bytes32 label = keccak256(bytes(name));
        if (data.length > 0 && resolver == address(0)) {
            revert ResolverRequiredWhenDataSupplied();
        }
        return keccak256(
            abi.encode(label, owner, duration, secret, resolver, data)
        );
    }

    function commit(bytes32 commitment) public {
        if (commitments[commitment] + maxCommitmentAge >= block.timestamp) {
            revert UnexpiredCommitmentExists(commitment);
        }
        commitments[commitment] = block.timestamp;
    }

    function register(
        string calldata name,
        address owner,
        uint256 duration,
        bytes32 secret,
        address resolver,
        bytes[] calldata data
    ) public payable {
        uint256 price = rentPrice(name, duration);
        if (msg.value < price) {
            revert InsufficientValue();
        }

        _consumeCommitment(
            name,
            duration,
            makeCommitment(name, owner, duration, secret, resolver, data)
        );

        uint256 expires = base.register(
            uint256(keccak256(bytes(name))),
            owner,
            duration
        );

        emit NameRegistered(
            name,
            keccak256(bytes(name)),
            owner,
            msg.value,
            expires
        );

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function renew(
        string calldata name,
        uint256 duration
    ) external payable {
        uint256 price = rentPrice(name, duration);
        if (msg.value < price) {
            revert InsufficientValue();
        }

        bytes32 labelhash = keccak256(bytes(name));
        uint256 expires = base.renew(uint256(labelhash), duration);

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        emit NameRenewed(name, labelhash, msg.value, expires);
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) external pure returns (bool) {
        return interfaceID == type(IERC165).interfaceId;
    }

    function _consumeCommitment(
        string memory name,
        uint256 duration,
        bytes32 commitment
    ) internal {
        // Require an old enough commitment
        if (commitments[commitment] + minCommitmentAge > block.timestamp) {
            revert CommitmentTooNew(commitment);
        }

        // If the commitment is too old, or the name is registered, stop
        if (commitments[commitment] + maxCommitmentAge <= block.timestamp) {
            revert CommitmentTooOld(commitment);
        }

        if (!available(name)) {
            revert NameNotAvailable(name);
        }

        delete (commitments[commitment]);

        if (duration < MIN_REGISTRATION_DURATION) {
            revert DurationTooShort(duration);
        }
    }
}