// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title ILiquidityMining
 * @notice Event interface for LP staking rewards module.
 *
 * @custom:version 1.0.0
 */
interface ILiquidityMining {
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event EmissionUpdated(uint256 rewardPerSecond);
}
