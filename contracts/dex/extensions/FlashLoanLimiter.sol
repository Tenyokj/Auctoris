// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IFlashLoanLimiter} from "../interfaces/IFlashLoanLimiter.sol";
import {DEXErrors} from "../common/DEXErrors.sol";

/**
 * @title FlashLoanLimiter
 * @notice Upgradeable policy contract enforcing flash-swap output limits.
 * @dev Uses OZ OwnableUpgradeable and PausableUpgradeable.
 *
 * @custom:version 1.0.0
 */
contract FlashLoanLimiter is Initializable, OwnableUpgradeable, PausableUpgradeable, IFlashLoanLimiter, DEXErrors {
    /* ========== CONSTANTS ========== */

    /// @notice Basis points denominator.
    uint256 public constant BPS = 10_000;

    /* ========== STATE VARIABLES ========== */

    /// @notice Default max out ratio in basis points.
    uint256 public defaultMaxOutBps;

    /// @notice Per-pool override max out ratio in basis points.
    mapping(address pool => uint256 maxOutBps) public poolMaxOutBps;

    /* ========== INITIALIZE ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes limiter contract.
     * @param owner_ Owner/admin address.
     * @param defaultMaxOutBps_ Default max out bps value.
     */
    function initialize(address owner_, uint256 defaultMaxOutBps_) external initializer {
        __Ownable_init(owner_);
        __Pausable_init();

        if (owner_ == address(0)) revert InvalidAddress();
        if (defaultMaxOutBps_ == 0 || defaultMaxOutBps_ >= BPS) revert InvalidBps();
        defaultMaxOutBps = defaultMaxOutBps_;
    }

    /* ========== ADMIN FUNCTIONS ========== */

    /**
     * @notice Sets default max out bps.
     */
    function setDefaultLimit(uint256 maxOutBps_) external onlyOwner whenNotPaused {
        if (maxOutBps_ == 0 || maxOutBps_ >= BPS) revert InvalidBps();
        defaultMaxOutBps = maxOutBps_;
        emit DefaultLimitUpdated(maxOutBps_);
    }

    /**
     * @notice Sets per-pool max out bps.
     */
    function setPoolLimit(address pool, uint256 maxOutBps_) external onlyOwner whenNotPaused {
        if (maxOutBps_ == 0 || maxOutBps_ >= BPS) revert InvalidBps();
        poolMaxOutBps[pool] = maxOutBps_;
        emit PoolLimitUpdated(pool, maxOutBps_);
    }

    /**
     * @notice Pauses limiter updates and checks.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses limiter.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /**
     * @inheritdoc IFlashLoanLimiter
     */
    function validateFlashSwap(
        address pool,
        address,
        uint256 reserveA,
        uint256 reserveB,
        uint256 amountAOut,
        uint256 amountBOut
    ) external view override whenNotPaused {
        uint256 limit = poolMaxOutBps[pool];
        if (limit == 0) limit = defaultMaxOutBps;

        if (amountAOut > (reserveA * limit) / BPS) revert LimitExceeded();
        if (amountBOut > (reserveB * limit) / BPS) revert LimitExceeded();
    }

    /* ========== UPGRADE SAFETY ========== */

    /// @dev Storage gap reserved for future variable additions.
    uint256[50] private __gap;
}
