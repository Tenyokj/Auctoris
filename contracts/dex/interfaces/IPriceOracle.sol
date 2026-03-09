// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IPriceOracle
 * @notice Event interface for TWAP oracle updates.
 *
 * @custom:version 1.0.0
 */
interface IPriceOracle {
    event OracleUpdated(address indexed pool, uint256 twapA, uint256 twapB, uint32 timestamp);
}
