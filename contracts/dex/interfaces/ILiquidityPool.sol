// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title ILiquidityPool
 * @notice Interface for AMM pool core operations and price views.
 * @dev Used by routers, oracle modules, and extensions.
 *
 * @custom:version 1.0.0
 */
interface ILiquidityPool {
    /// @notice Emitted when liquidity is minted.
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 mintedShares);
    /// @notice Emitted when liquidity is burned.
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 burnedShares);
    /// @notice Emitted on token swap execution.
    event SwapExecuted(address indexed trader, address indexed tokenIn, address indexed tokenOut, uint256 amountOut);
    /// @notice Emitted on ETH->token swap execution.
    event SwapEthForToken(address indexed trader, uint256 amountInEth, address indexed tokenOut, uint256 amountOut);
    /// @notice Emitted on token->ETH swap execution.
    event SwapTokenForEth(address indexed trader, address indexed tokenIn, uint256 amountIn, uint256 amountOutEth);
    /// @notice Emitted when protocol fee is paid out.
    event ProtocolFeePaid(address indexed token, address indexed recipient, uint256 amount);
    /// @notice Emitted whenever reserves are synchronized to balances.
    event Synced(uint256 reserveA, uint256 reserveB);
    /// @notice Emitted when surplus balances are skimmed.
    event Skimmed(address indexed to, uint256 amountA, uint256 amountB);

    /**
     * @notice Returns tokenA address for this pool.
     */
    function tokenA() external view returns (address);
    /**
     * @notice Returns tokenB address for this pool.
     */
    function tokenB() external view returns (address);
    /**
     * @notice Returns current reserve amount of tokenA.
     */
    function reserveA() external view returns (uint256);
    /**
     * @notice Returns current reserve amount of tokenB.
     */
    function reserveB() external view returns (uint256);

    /**
     * @notice Mints LP shares from balances already transferred to the pool.
     * @param minShares Minimum acceptable LP shares (slippage guard).
     * @param deadline Expiration timestamp for transaction validity.
     * @return shares Minted LP share amount.
     */
    function addLiquidityFromBalances(uint256 minShares, uint256 deadline) external returns (uint256 shares);
    /**
     * @notice Burns LP shares and returns underlying tokens pro-rata.
     * @param liquidityShare LP token amount to burn.
     * @param amountAMin Minimum acceptable tokenA out.
     * @param amountBMin Minimum acceptable tokenB out.
     * @param deadline Expiration timestamp for transaction validity.
     */
    function removeLiquidity(uint256 liquidityShare, uint256 amountAMin, uint256 amountBMin, uint256 deadline)
        external
        returns (uint256 amountA, uint256 amountB);

    /**
     * @notice Executes exact-input swap where input tokens are pre-transferred to pool.
     * @param tokenIn Input token address.
     * @param amountOutMin Minimum acceptable output amount.
     * @param deadline Expiration timestamp for transaction validity.
     */
    function swap(address tokenIn, uint256 amountOutMin, uint256 deadline) external returns (uint256 amountOut);
    /**
     * @notice Executes flash swap and invokes callback on receiver contract.
     * @param amountAOut tokenA amount borrowed.
     * @param amountBOut tokenB amount borrowed.
     * @param to Receiver/callback address.
     * @param data Arbitrary callback payload.
     * @param deadline Expiration timestamp for transaction validity.
     */
    function flashSwap(uint256 amountAOut, uint256 amountBOut, address to, bytes calldata data, uint256 deadline) external;
    /**
     * @notice Quotes output amount for given input and reserves.
     * @param amountIn Input amount.
     * @param reserveIn Input-side reserve.
     * @param reserveOut Output-side reserve.
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external view returns (uint256 amountOut);
    /**
     * @notice Returns cumulative price values and current timestamp for TWAP usage.
     */
    function currentCumulativePrices()
        external
        view
        returns (uint256 priceACumulative, uint256 priceBCumulative, uint32 blockTimestamp);

    /**
     * @notice Synchronizes reserves to current token balances.
     */
    function sync() external;

    /**
     * @notice Transfers surplus token balances above reserves to recipient.
     * @param to Recipient address.
     */
    function skim(address to) external;
}
