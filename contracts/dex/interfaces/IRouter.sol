// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IRouter
 * @notice Minimal router interface used by RouterV2 helper.
 * @dev Provides canonical external swap entrypoint.
 *
 * @custom:version 1.0.0
 */
interface IRouter {
    /// @notice Emitted when router adds liquidity on behalf of user.
    event RouterLiquidityAdded(
        address indexed provider,
        address indexed pool,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );
    /// @notice Emitted when router removes liquidity on behalf of user.
    event RouterLiquidityRemoved(
        address indexed provider,
        address indexed pool,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );
    /// @notice Emitted for router-level swap execution summary.
    event RouterSwap(
        address indexed sender,
        address indexed to,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    /**
     * @notice Swaps exact input tokens across provided path.
     * @param amountIn Exact input token amount.
     * @param amountOutMin Minimum acceptable final output.
     * @param path Ordered token path for hop execution.
     * @param to Final receiver address.
     * @param deadline Expiration timestamp for transaction validity.
     * @return amounts Per-hop amounts including input at index 0.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
