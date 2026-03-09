// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IFlashLoanLimiter
 * @notice External policy hook that validates flash swap size/rate limits.
 *
 * @custom:version 1.0.0
 */
interface IFlashLoanLimiter {
    /// @notice Emitted when default max-out limit is updated.
    event DefaultLimitUpdated(uint256 maxOutBps);
    /// @notice Emitted when pool-specific max-out limit is updated.
    event PoolLimitUpdated(address indexed pool, uint256 maxOutBps);

    /**
     * @notice Validates requested flash swap sizes against limiter policy.
     * @param pool Pool contract performing validation.
     * @param caller Original flash swap caller.
     * @param reserveA Pre-swap reserveA.
     * @param reserveB Pre-swap reserveB.
     * @param amountAOut Requested tokenA flash out.
     * @param amountBOut Requested tokenB flash out.
     */
    function validateFlashSwap(
        address pool,
        address caller,
        uint256 reserveA,
        uint256 reserveB,
        uint256 amountAOut,
        uint256 amountBOut
    ) external view;
}
