// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IPoolFactory} from "./IPoolFactory.sol";

/**
 * @title IPoolFactoryAdmin
 * @notice Extended factory interface with privileged admin controls.
 * @dev Used by governance modules that manage protocol parameters.
 *
 * @custom:version 1.0.0
 */
interface IPoolFactoryAdmin is IPoolFactory {
    /**
     * @notice Updates global fee configuration.
     * @param swapFeeBps_ Total swap fee in basis points.
     * @param protocolFeeBps_ Protocol fee share in basis points.
     * @param feeReceiver_ Protocol treasury address.
     */
    function setFeeConfig(uint256 swapFeeBps_, uint256 protocolFeeBps_, address feeReceiver_) external;

    /**
     * @notice Sets flash loan limiter contract.
     * @param limiter Limiter contract address.
     */
    function setFlashLoanLimiter(address limiter) external;

    /**
     * @notice Pauses factory and dependent protocol flows.
     */
    function pause() external;

    /**
     * @notice Unpauses factory and dependent protocol flows.
     */
    function unpause() external;
}
