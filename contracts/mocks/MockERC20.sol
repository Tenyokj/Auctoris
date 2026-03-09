// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Mintable ERC20 token for local testing.
 * @dev Intended only for tests; no access control on mint.
 *
 * @custom:version 1.0.0
 */
contract MockERC20 is ERC20 {
    /**
     * @notice Deploys mock token.
     * @param name_ ERC20 token name.
     * @param symbol_ ERC20 token symbol.
     */
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    /**
     * @notice Mints tokens to recipient.
     * @param to Recipient address.
     * @param amount Amount to mint.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

