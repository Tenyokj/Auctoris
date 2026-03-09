// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IPoolFactory
 * @notice Interface for pool discovery and global AMM configuration.
 * @dev Routers and auxiliary contracts query this interface for pool addresses and policy settings.
 *
 * @custom:version 1.0.0
 */
interface IPoolFactory {
    /// @notice Emitted when new pool is created for token pair.
    /// @param token0 Sorted lower-address token.
    /// @param token1 Sorted higher-address token.
    /// @param pool Created pool address.
    /// @param poolCount New total pool count.
    event PoolCreated(address indexed token0, address indexed token1, address pool, uint256 poolCount);

    /// @notice Emitted when factory fee configuration is updated.
    /// @param swapFeeBps Total swap fee in basis points.
    /// @param protocolFeeBps Protocol fee share in basis points.
    /// @param feeReceiver Protocol fee receiver address.
    event FeeConfigUpdated(uint256 swapFeeBps, uint256 protocolFeeBps, address feeReceiver);

    /// @notice Emitted when flash-loan limiter address is updated.
    /// @param limiter New limiter contract address.
    event FlashLoanLimiterUpdated(address indexed limiter);

    /**
     * @notice Returns WETH address configured for protocol.
     */
    function WETH() external view returns (address);
    /**
     * @notice Returns pool address for pair or zero if missing.
     * @param tokenA First token address.
     * @param tokenB Second token address.
     */
    function getPool(address tokenA, address tokenB) external view returns (address);
    /**
     * @notice Creates pool for pair if not existing.
     * @param tokenA First token address.
     * @param tokenB Second token address.
     * @return pool Address of newly created pool.
     */
    function createPool(address tokenA, address tokenB) external returns (address);
    /**
     * @notice Returns total number of created pools.
     */
    function allPoolsLength() external view returns (uint256);

    /**
     * @notice Returns total swap fee in basis points.
     */
    function swapFeeBps() external view returns (uint256);
    /**
     * @notice Returns protocol share of swap fee in basis points.
     */
    function protocolFeeBps() external view returns (uint256);
    /**
     * @notice Returns address receiving protocol fees.
     */
    function feeReceiver() external view returns (address);
    /**
     * @notice Returns protocol pause state.
     */
    function paused() external view returns (bool);
    /**
     * @notice Returns flash swap limiter address.
     */
    function flashLoanLimiter() external view returns (address);
}
