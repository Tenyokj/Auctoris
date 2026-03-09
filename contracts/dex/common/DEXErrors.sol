// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title DEXErrors
 * @notice Shared custom error definitions for all DEX modules.
 * @dev Contracts inherit this abstract contract to enforce a unified error standard.
 *
 * @custom:version 1.0.0
 */
abstract contract DEXErrors {
    /// @notice Thrown when provided token address is unsupported or invalid.
    error InvalidToken();

    /// @notice Thrown when amount is zero but positive value is required.
    error ZeroAmount();

    /// @notice Thrown when pool or operation lacks sufficient liquidity.
    error InsufficientLiquidity();

    /// @notice Thrown when output amount is below required minimum.
    error InsufficientOutputAmount();

    /// @notice Thrown when slippage protection threshold is violated.
    error SlippageExceeded();

    /// @notice Thrown when operation deadline has passed.
    error DeadlineExpired();

    /// @notice Thrown when WETH address is missing or invalid.
    error InvalidWETH();

    /// @notice Thrown when ETH-specific path is used in non-ETH pool.
    error EthNotSupported();

    /// @notice Thrown when low-level transfer call fails.
    error TransferFailed();

    /// @notice Thrown when recipient address is invalid.
    error InvalidRecipient();

    /// @notice Thrown when factory address is invalid.
    error InvalidFactory();

    /// @notice Thrown when fee configuration values are invalid.
    error InvalidFeeConfig();

    /// @notice Thrown when detected input amount is insufficient.
    error InsufficientInputAmount();

    /// @notice Thrown when flash swap request is malformed.
    error InvalidFlashSwap();

    /// @notice Thrown when AMM invariant validation fails.
    error InvalidK();

    /// @notice Thrown when protocol is paused.
    error ProtocolPaused();

    /// @notice Thrown when token pair addresses are identical.
    error IdenticalTokenAddresses();

    /// @notice Thrown when zero-address token is provided.
    error ZeroAddressToken();

    /// @notice Thrown when pool already exists for given pair.
    error PoolAlreadyExists();

    /// @notice Thrown when limiter address is invalid.
    error InvalidLimiter();

    /// @notice Thrown when provided route/path is invalid.
    error InvalidPath();

    /// @notice Thrown when generic address parameter is invalid.
    error InvalidAddress();

    /// @notice Thrown when operation amount constraints are not met.
    error InsufficientAmount();

    /// @notice Thrown when requested pool is not found.
    error PoolNotFound();

    /// @notice Thrown when hop-level slippage array is malformed.
    error InvalidHopMins();

    /// @notice Thrown when timelock delay requirement is not met.
    error DelayNotMet();

    /// @notice Thrown when action hash has not been queued.
    error ActionNotQueued();

    /// @notice Thrown when action hash is already queued.
    error ActionAlreadyQueued();

    /// @notice Thrown when flash-loan limit policy is exceeded.
    error LimitExceeded();

    /// @notice Thrown when basis-points value is outside allowed range.
    error InvalidBps();

    /// @notice Thrown when oracle observation is not initialized.
    error NotInitialized();

    /// @notice Thrown when oracle update interval is too short.
    error StaleObservation();

    /// @notice Thrown when no valid route exists for swap request.
    error NoRoute();

    /// @notice Thrown when user tries to withdraw more stake than available.
    error InsufficientStake();

    /// @notice Thrown when related array lengths do not match.
    error LengthMismatch();

    /// @notice Thrown when external call fails.
    error ExternalCallFailed();

    /// @notice Thrown when governance delay is configured with invalid value.
    error InvalidDelay();

    /// @notice Thrown when contract token balance is lower than requested transfer amount.
    error InsufficientContractBalance();
}
