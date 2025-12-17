// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IKanaRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockKanaRouter
 * @notice Mock Kana router for testing swaps
 */
contract MockKanaRouter is IKanaRouter {
    // Simulated exchange rate: 1:1 for simplicity
    uint256 public exchangeRate = 1e18;
    uint256 public slippagePercent = 50; // 0.5%

    function setExchangeRate(uint256 rate) external {
        exchangeRate = rate;
    }

    function setSlippage(uint256 slippage) external {
        slippagePercent = slippage;
    }

    function executeSwap(SwapIntent memory intent) external override returns (uint256 amountOut) {
        // Transfer input tokens from sender
        IERC20(intent.fromToken).transferFrom(msg.sender, address(this), intent.amountIn);

        // Calculate output with simulated exchange rate and slippage
        amountOut = (intent.amountIn * exchangeRate) / 1e18;
        uint256 slippageAmount = (amountOut * slippagePercent) / 10000;
        amountOut = amountOut - slippageAmount;

        require(amountOut >= intent.minAmountOut, "Slippage too high");

        // Mint output tokens to sender (in real scenario, router would have liquidity)
        // For testing, we'll just transfer from router's balance
        IERC20(intent.toToken).transfer(msg.sender, amountOut);

        emit SwapExecuted(
            msg.sender,
            intent.fromToken,
            intent.toToken,
            intent.amountIn,
            amountOut,
            bytes32(0)
        );
    }

    function simulateRoute(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) external view override returns (uint256 estimatedOut, uint256 gasCost) {
        estimatedOut = (amountIn * exchangeRate) / 1e18;
        uint256 slippageAmount = (estimatedOut * slippagePercent) / 10000;
        estimatedOut = estimatedOut - slippageAmount;
        gasCost = 150000; // Estimated gas
    }

    function getSupportedBridges() external pure override returns (bytes32[] memory) {
        bytes32[] memory bridges = new bytes32[](3);
        bridges[0] = keccak256("LayerZero");
        bridges[1] = keccak256("Wormhole");
        bridges[2] = keccak256("Axelar");
        return bridges;
    }

    // Helper function to fund router with tokens for testing
    function fundRouter(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }
}
