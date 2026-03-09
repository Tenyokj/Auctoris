// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DEXErrors} from "../common/DEXErrors.sol";
import {IFeeCollector} from "../interfaces/IFeeCollector.sol";

/**
 * @title FeeCollector
 * @notice Upgradeable protocol treasury vault for accumulated ERC20 fees.
 * @dev Uses OZ OwnableUpgradeable and PausableUpgradeable.
 *
 * @custom:version 1.0.0
 */
contract FeeCollector is Initializable, OwnableUpgradeable, PausableUpgradeable, IFeeCollector, DEXErrors {
    using SafeERC20 for IERC20;

    /* ========== INITIALIZE ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes fee collector.
     * @param owner_ Owner/admin address.
     */
    function initialize(address owner_) external initializer {
        __Ownable_init(owner_);
        __Pausable_init();
        if (owner_ == address(0)) revert InvalidAddress();
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /**
     * @notice Withdraws specific token amount to recipient.
     */
    function withdraw(address token, address recipient, uint256 amount) external onlyOwner whenNotPaused {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert ZeroAmount();
        if (IERC20(token).balanceOf(address(this)) < amount) revert InsufficientContractBalance();

        IERC20(token).safeTransfer(recipient, amount);
        emit FeeWithdrawn(token, recipient, amount);
    }

    /**
     * @notice Batch withdraw for multiple token transfers.
     */
    function batchWithdraw(address[] calldata tokens, address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyOwner
        whenNotPaused
    {
        uint256 len = tokens.length;
        if (len != recipients.length || len != amounts.length) revert LengthMismatch();

        for (uint256 i = 0; i < len; i++) {
            if (recipients[i] == address(0)) revert InvalidRecipient();
            if (amounts[i] == 0) revert ZeroAmount();
            if (IERC20(tokens[i]).balanceOf(address(this)) < amounts[i]) revert InsufficientContractBalance();
            IERC20(tokens[i]).safeTransfer(recipients[i], amounts[i]);
            emit FeeWithdrawn(tokens[i], recipients[i], amounts[i]);
        }
    }

    /**
     * @notice Emergency withdrawal path available while contract is paused.
     * @dev Allows treasury evacuation during incident response.
     * @param token ERC20 token address.
     * @param recipient Receiver address.
     * @param amount Amount to withdraw.
     */
    function emergencyWithdraw(address token, address recipient, uint256 amount) external onlyOwner whenPaused {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert ZeroAmount();
        if (IERC20(token).balanceOf(address(this)) < amount) revert InsufficientContractBalance();

        IERC20(token).safeTransfer(recipient, amount);
        emit FeeWithdrawn(token, recipient, amount);
    }

    /**
     * @notice Pauses treasury withdrawals.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses treasury withdrawals.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /* ========== UPGRADE SAFETY ========== */

    /// @dev Storage gap reserved for future variable additions.
    uint256[50] private __gap;
}
