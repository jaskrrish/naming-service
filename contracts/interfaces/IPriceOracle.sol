// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPriceOracle {
    function price(string memory name, uint256 duration) external view returns (uint256);
}
