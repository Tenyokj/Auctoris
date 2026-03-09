// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IPoolFactoryConfig
 * @notice Read-only interface for pool-level access to global factory configuration.
 * @dev Pools use this interface to fetch fee and pause settings from factory.
 *
 * @custom:version 1.0.0
 */
interface IPoolFactoryConfig {
    /**
     * @notice Returns total swap fee in basis points.
     */
    function swapFeeBps() external view returns (uint256);

    /**
     * @notice Returns protocol share of swap fee in basis points.
     */
    function protocolFeeBps() external view returns (uint256);

    /**
     * @notice Returns receiver address for protocol fee transfers.
     */
    function feeReceiver() external view returns (address);

    /**
     * @notice Returns global pause state.
     */
    function paused() external view returns (bool);

    /**
     * @notice Returns optional flash loan limiter contract address.
     */
    function flashLoanLimiter() external view returns (address);
}
