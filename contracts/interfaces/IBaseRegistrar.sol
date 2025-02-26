//SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IBaseRegistrar {
    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);
    event NameRegistered(uint256 indexed id, address indexed owner, uint256 expires);
    event NameRenewed(uint256 indexed id, uint256 expires);

    function addController(address controller) external;
    function removeController(address controller) external;
    function setResolver(address resolver) external;
    function register(uint256 id, address owner, uint256 duration) external returns (uint256);
    function renew(uint256 id, uint256 duration) external returns (uint256);
    function available(uint256 id) external view returns (bool);
    function nameExpires(uint256 id) external view returns (uint256);
}
