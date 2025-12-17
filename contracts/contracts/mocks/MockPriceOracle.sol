// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IPriceOracle.sol";

/**
 * @title MockPriceOracle
 * @notice Mock price oracle for testing
 */
contract MockPriceOracle is IPriceOracle {
    mapping(address => uint256) private prices;
    mapping(address => bytes32) private sources;

    function setPrice(address token, uint256 priceInUsdc) external {
        prices[token] = priceInUsdc;
        sources[token] = "MOCK";
    }

    function getPrice(address token) external view override returns (uint256 priceInUsdc, uint256 confidence) {
        priceInUsdc = prices[token];
        confidence = 10000; // 100% confidence
    }

    function getPrices(address[] memory tokens) external view override returns (uint256[] memory) {
        uint256[] memory results = new uint256[](tokens.length);
        for (uint i = 0; i < tokens.length; i++) {
            results[i] = prices[tokens[i]];
        }
        return results;
    }

    function validatePrice(address token, uint256 executionPrice) external view override returns (bool) {
        uint256 oraclePrice = prices[token];
        if (oraclePrice == 0) return true;
        
        uint256 deviation = executionPrice > oraclePrice 
            ? (executionPrice - oraclePrice) * 10000 / oraclePrice
            : (oraclePrice - executionPrice) * 10000 / oraclePrice;
        
        return deviation <= 150; // 1.5% max deviation
    }

    function getPriceSource(address token) external view override returns (bytes32) {
        return sources[token];
    }
}
