// contracts/ReverseRegistrar.sol
pragma solidity ^0.8.19;

import "./Controllable.sol";
import "./interfaces/IPushRegistry.sol";
import "./interfaces/IResolver.sol";
import "./utils/Errors.sol";

contract ReverseRegistrar is Controllable {
    // namehash of addr.reverse
    bytes32 constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    // Used in assembly to convert an address to a hex string - ASCII codes for "0123456789abcdef"
    bytes32 constant lookup = 0x3031323334353637383961626364656600000000000000000000000000000000;

    IPNS public immutable registry;
    IResolver public defaultResolver;

    event ReverseClaimed(address indexed addr, bytes32 indexed node);
    event DefaultResolverChanged(IResolver indexed resolver);

    constructor(IPNS _registry) {
        if (address(_registry) == address(0)) revert InvalidAddress(address(0));
        registry = _registry;

        ReverseRegistrar oldRegistrar = ReverseRegistrar(
            _registry.owner(ADDR_REVERSE_NODE)
        );
        if (address(oldRegistrar) != address(0x0)) {
            oldRegistrar.claim(msg.sender);
        }
    }

    modifier authorised(address addr) {
        if (!(
            addr == msg.sender ||
            controllers[msg.sender] ||
            registry.isApprovedForAll(addr, msg.sender) ||
            ownsContract(addr)
        )) revert NotAuthorised();
        _;
    }

    function setDefaultResolver(address resolver) public onlyOwner {
        if (address(resolver) == address(0)) revert ResolverRequired();
        defaultResolver = IResolver(resolver);
        emit DefaultResolverChanged(IResolver(resolver));
    }

    function claim(address owner) public returns (bytes32) {
        return claimForAddr(msg.sender, owner, address(defaultResolver));
    }

    function claimForAddr(
        address addr,
        address owner,
        address resolver
    ) public authorised(addr) returns (bytes32) {
        bytes32 labelHash = sha3HexAddress(addr);
        bytes32 reverseNode = keccak256(
            abi.encodePacked(ADDR_REVERSE_NODE, labelHash)
        );
        emit ReverseClaimed(addr, reverseNode);
        registry.setSubnodeRecord(ADDR_REVERSE_NODE, labelHash, owner, resolver, 0);
        return reverseNode;
    }

    function claimWithResolver(address owner, address resolver) public returns (bytes32) {
        return claimForAddr(msg.sender, owner, resolver);
    }

    function setName(string memory name) public returns (bytes32) {
        return setNameForAddr(msg.sender, msg.sender, address(defaultResolver), name);
    }

    function setNameForAddr(
        address addr,
        address owner,
        address resolver,
        string memory name
    ) public authorised(addr) returns (bytes32) {
        bytes32 node = claimForAddr(addr, owner, resolver);
        IResolver(resolver).setName(node, name);
        return node;
    }

    function node(address addr) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr))
        );
    }

    function sha3HexAddress(address addr) private pure returns (bytes32 ret) {
        assembly {
            for { let i := 40 } gt(i, 0) { } {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }
            ret := keccak256(0, 40)
        }
    }

    function ownsContract(address addr) internal view returns (bool) {
        try Ownable(addr).owner() returns (address owner) {
            return owner == msg.sender;
        } catch {
            return false;
        }
    }
}