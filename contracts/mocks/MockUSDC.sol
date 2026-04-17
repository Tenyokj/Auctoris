// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title MockUSDC
 * @notice Simple ERC20 + ERC20Permit token used for testing ERC20 payment flows.
 * @dev Mimics USDC-style 6 decimal behavior.
 * @custom:version 1.0.1
 */
contract MockUSDC is ERC20, ERC20Permit {
    /// @notice Initializes the mock token metadata and permit domain.
    constructor() ERC20("Mock USDC", "mUSDC") ERC20Permit("Mock USDC") {}

    /// @notice Returns the number of token decimals.
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @notice Mints test tokens to an address.
     * @param to The token recipient.
     * @param amount The amount to mint.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
