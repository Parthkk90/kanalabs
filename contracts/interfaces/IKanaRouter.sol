// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IKanaRouter
 * @notice Interface for Kana Labs Aggregator Router
 */
interface IKanaRouter {
    struct SwapIntent {
        address fromToken;
        address toToken;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
        bytes routeData; // Kana route bytes from off-chain SDK
    }

    /**
     * @notice Execute a swap through Kana aggregator
     * @param intent Swap parameters
     * @return amountOut Actual output amount received
     */
    function executeSwap(SwapIntent memory intent) external returns (uint256 amountOut);

    /**
     * @notice Simulate a route to get expected output
     * @param fromToken Source token address
     * @param toToken Destination token address
     * @param amountIn Input amount
     * @return estimatedOut Expected output amount
     * @return gasCost Estimated gas cost in native token
     */
    function simulateRoute(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) external view returns (uint256 estimatedOut, uint256 gasCost);

    /**
     * @notice Get supported bridges for cross-chain swaps
     * @return bridges Array of bridge identifiers
     */
    function getSupportedBridges() external view returns (bytes32[] memory bridges);

    event SwapExecuted(
        address indexed user,
        address indexed fromToken,
        address indexed toToken,
        uint256 amountIn,
        uint256 amountOut,
        bytes32 routeId
    );

    event BridgeInitiated(
        address indexed user,
        uint256 indexed sourceChain,
        uint256 indexed destChain,
        bytes32 bridgeId,
        uint256 amount
    );
}
