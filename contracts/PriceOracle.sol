// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {StringUtils} from "@ensdomains/ens-contracts/contracts/utils/StringUtils.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import "./interfaces/IPriceOracle.sol";
import "./utils/Errors.sol";

contract PriceOracle is IPriceOracle, Ownable {
    using StringUtils for *;

    struct PriceConfig {
        uint256 price1Letter;
        uint256 price2Letter;
        uint256 price3Letter;
        uint256 price4Letter;
        uint256 price5Letter;
    }

    PriceConfig public prices;
    
    event PricesUpdated(PriceConfig prices);

    constructor(uint256[] memory _rentPrices) {
        if (_rentPrices.length != 5) revert InvalidPrice(_rentPrices.length);
        for(uint i = 0; i < 5; i++) {
            if(_rentPrices[i] == 0) revert InvalidPrice(_rentPrices[i]);
        }
        
        prices = PriceConfig({
            price1Letter: _rentPrices[0],
            price2Letter: _rentPrices[1],
            price3Letter: _rentPrices[2],
            price4Letter: _rentPrices[3],
            price5Letter: _rentPrices[4]
        });
    }

    function updatePrices(PriceConfig calldata _prices) external onlyOwner {
        if (_prices.price1Letter == 0 || 
            _prices.price2Letter == 0 || 
            _prices.price3Letter == 0 || 
            _prices.price4Letter == 0 || 
            _prices.price5Letter == 0) revert InvalidPrice(0);
            
        prices = _prices;
        emit PricesUpdated(_prices);
    }

    function price(
        string calldata name,
        uint256 duration
    ) external view override returns (uint256) {
        if (duration < 1 days) revert InvalidDuration(duration);
        
        uint256 len = name.strlen();
        uint256 basePrice;

        if (len == 1) {
            basePrice = prices.price1Letter;
        } else if (len == 2) {
            basePrice = prices.price2Letter;
        } else if (len == 3) {
            basePrice = prices.price3Letter;
        } else if (len == 4) {
            basePrice = prices.price4Letter;
        } else {
            basePrice = prices.price5Letter;
        }

        uint256 durationInDays = duration / 1 days;
        return basePrice * durationInDays;
    }
}