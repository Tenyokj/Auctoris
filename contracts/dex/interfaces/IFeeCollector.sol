// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IFeeCollector
 * @notice Interface for protocol treasury fee vault.
 *
 * @custom:version 1.0.0
 */
interface IFeeCollector {
    /// @notice Emitted when fee tokens are withdrawn from treasury.
    event FeeWithdrawn(address indexed token, address indexed recipient, uint256 amount);
}
