// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title FATK - Flash Alliance Token
/// @notice ERC20 token used to fund and settle FlashAlliance deals.
/// @dev Owner can mint and pause token transfers.
/// @custom:version 1.0.0
contract FATK is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ERC20Permit {
    /// @notice Deploys token contract.
    /// @param initialOwner Owner with mint/pause permissions.
    constructor(address initialOwner)
        ERC20("FlashAlliance Token", "FATK")
        Ownable(initialOwner)
        ERC20Permit("FlashAlliance Token")
    {}

    /// @notice Pause all token transfers.
    /// @dev Affects transfers, minting, and burning through ERC20Pausable's `_update` hook.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause token transfers.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Mint tokens to recipient.
    /// @param to Recipient address.
    /// @param amount Amount to mint.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @inheritdoc ERC20
    /// @dev Resolves multiple inheritance between `ERC20` and `ERC20Pausable`.
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
