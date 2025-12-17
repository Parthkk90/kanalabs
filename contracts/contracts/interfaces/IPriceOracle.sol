// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IPriceOracle
 * @notice Interface for multi-source price oracle adapter
 */
interface IPriceOracle {
    /**
     * @notice Get price of a token in USDC
     * @param token Token address
     * @return priceInUsdc Price with 18 decimals precision
     * @return confidence Confidence score (0-10000 bps, 10000 = 100%)
     */
    function getPrice(address token) external view returns (uint256 priceInUsdc, uint256 confidence);

    /**
     * @notice Get prices for multiple tokens in batch
     * @param tokens Array of token addresses
     * @return prices Array of prices in USDC (18 decimals)
     */
    function getPrices(address[] memory tokens) external view returns (uint256[] memory prices);

    /**
     * @notice Validate if execution price is within acceptable deviation
     * @param token Token address
     * @param executionPrice Actual execution price
     * @return valid True if within deviation threshold
     */
    function validatePrice(address token, uint256 executionPrice) external view returns (bool valid);

    /**
     * @notice Get primary oracle source for a token
     * @param token Token address
     * @return source Oracle source identifier (e.g., "CHAINLINK", "PYTH", "KANA")
     */
    function getPriceSource(address token) external view returns (bytes32 source);

    event PriceUpdated(
        address indexed token,
        uint256 oldPrice,
        uint256 newPrice,
        bytes32 source,
        uint256 timestamp
    );

    event PriceDeviationAlert(
        address indexed token,
        uint256 oraclePrice,
        uint256 executionPrice,
        uint256 deviationBps
    );
}
