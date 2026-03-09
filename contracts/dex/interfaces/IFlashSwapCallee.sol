// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IFlashSwapCallee
 * @notice Callback interface invoked by pools during flash swap execution.
 * @dev Receiver contract must return borrowed assets (plus fee) before transaction end.
 *
 * @custom:version 1.0.0
 */
interface IFlashSwapCallee {
    /**
     * @notice Callback hook executed by pool after sending flash swap amounts.
     * @param sender Original caller who initiated `flashSwap`.
     * @param amountAOut Borrowed amount of tokenA.
     * @param amountBOut Borrowed amount of tokenB.
     * @param data Arbitrary callback payload forwarded from pool.
     */
    function flashSwapCall(address sender, uint256 amountAOut, uint256 amountBOut, bytes calldata data) external;
}
