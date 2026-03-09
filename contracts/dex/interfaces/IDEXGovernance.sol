// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IDEXGovernance
 * @notice Event interface for timelocked governance executor.
 *
 * @custom:version 1.0.0
 */
interface IDEXGovernance {
    /// @notice Emitted when action is queued with execution time.
    event ActionQueued(bytes32 indexed actionId, uint256 executeAfter);
    /// @notice Emitted when queued action is executed.
    event ActionExecuted(bytes32 indexed actionId);
    /// @notice Emitted when queued action is cancelled.
    event ActionCancelled(bytes32 indexed actionId);
}
