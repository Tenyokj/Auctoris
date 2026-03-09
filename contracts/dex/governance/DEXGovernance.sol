// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IPoolFactoryAdmin} from "../interfaces/IPoolFactoryAdmin.sol";
import {IDEXGovernance} from "../interfaces/IDEXGovernance.sol";
import {DEXErrors} from "../common/DEXErrors.sol";

/**
 * @title DEXGovernance
 * @notice Upgradeable timelocked governance executor for PoolFactory admin actions.
 * @dev Deploy behind TransparentUpgradeableProxy and initialize with owner/factory.
 * @dev Uses OpenZeppelin OwnableUpgradeable and PausableUpgradeable.
 *
 * @custom:version 1.0.0
 */
contract DEXGovernance is Initializable, OwnableUpgradeable, PausableUpgradeable, IDEXGovernance, DEXErrors {
    /* ========== STATE VARIABLES ========== */

    /// @notice Controlled factory admin interface.
    IPoolFactoryAdmin public factory;

    /// @notice Minimum delay in seconds before queued action can be executed.
    uint256 public minDelay;

    /// @notice Mapping action hash => earliest execution timestamp.
    mapping(bytes32 actionId => uint256 eta) public queuedActions;

    /* ========== INITIALIZE ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes governance contract for proxy deployment.
     * @param owner_ Governance owner address.
     * @param factory_ PoolFactory admin contract address.
     * @param minDelaySeconds Minimum governance delay.
     */
    function initialize(address owner_, address factory_, uint256 minDelaySeconds) external initializer {
        __Ownable_init(owner_);
        __Pausable_init();

        if (owner_ == address(0) || factory_ == address(0)) revert InvalidAddress();
        if (minDelaySeconds == 0) revert InvalidDelay();

        factory = IPoolFactoryAdmin(factory_);
        minDelay = minDelaySeconds;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /**
     * @notice Queues fee-config update action.
     */
    function queueSetFeeConfig(uint256 swapFeeBps, uint256 protocolFeeBps, address feeReceiver)
        external
        onlyOwner
        whenNotPaused
        returns (bytes32 actionId)
    {
        actionId = keccak256(abi.encode("setFeeConfig", swapFeeBps, protocolFeeBps, feeReceiver));
        _queue(actionId);
    }

    /**
     * @notice Executes queued fee-config update action.
     */
    function executeSetFeeConfig(uint256 swapFeeBps, uint256 protocolFeeBps, address feeReceiver)
        external
        onlyOwner
        whenNotPaused
    {
        bytes32 actionId = keccak256(abi.encode("setFeeConfig", swapFeeBps, protocolFeeBps, feeReceiver));
        _consume(actionId);
        factory.setFeeConfig(swapFeeBps, protocolFeeBps, feeReceiver);
        emit ActionExecuted(actionId);
    }

    /**
     * @notice Queues factory pause-state change.
     */
    function queueSetEmergencyPause(bool paused_) external onlyOwner whenNotPaused returns (bytes32 actionId) {
        actionId = keccak256(abi.encode("setPause", paused_));
        _queue(actionId);
    }

    /**
     * @notice Executes queued factory pause-state change.
     */
    function executeSetEmergencyPause(bool paused_) external onlyOwner whenNotPaused {
        bytes32 actionId = keccak256(abi.encode("setPause", paused_));
        _consume(actionId);
        if (paused_) {
            factory.pause();
        } else {
            factory.unpause();
        }
        emit ActionExecuted(actionId);
    }

    /**
     * @notice Queues flash-loan limiter update.
     */
    function queueSetFlashLoanLimiter(address limiter) external onlyOwner whenNotPaused returns (bytes32 actionId) {
        actionId = keccak256(abi.encode("setFlashLoanLimiter", limiter));
        _queue(actionId);
    }

    /**
     * @notice Executes queued flash-loan limiter update.
     */
    function executeSetFlashLoanLimiter(address limiter) external onlyOwner whenNotPaused {
        bytes32 actionId = keccak256(abi.encode("setFlashLoanLimiter", limiter));
        _consume(actionId);
        factory.setFlashLoanLimiter(limiter);
        emit ActionExecuted(actionId);
    }

    /**
     * @notice Cancels queued action.
     * @param actionId Action hash.
     */
    function cancel(bytes32 actionId) external onlyOwner {
        if (queuedActions[actionId] == 0) revert ActionNotQueued();
        delete queuedActions[actionId];
        emit ActionCancelled(actionId);
    }

    /**
     * @notice Pauses governance mutative operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses governance mutative operations.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
     * @notice Queues action hash with execution timestamp.
     */
    function _queue(bytes32 actionId) internal {
        if (queuedActions[actionId] != 0) revert ActionAlreadyQueued();
        uint256 executeAfter = block.timestamp + minDelay;
        queuedActions[actionId] = executeAfter;
        emit ActionQueued(actionId, executeAfter);
    }

    /**
     * @notice Consumes queued action and verifies timelock.
     */
    function _consume(bytes32 actionId) internal {
        uint256 eta = queuedActions[actionId];
        if (eta == 0) revert ActionNotQueued();
        if (block.timestamp < eta) revert DelayNotMet();
        delete queuedActions[actionId];
    }

    /* ========== UPGRADE SAFETY ========== */

    /// @dev Storage gap reserved for future variable additions.
    uint256[50] private __gap;
}
