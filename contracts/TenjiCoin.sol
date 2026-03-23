// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title TenjiCoin
 * @notice Fixed-supply ERC20 meme token for the Tenji project.
 * @dev Mints the entire supply once during deployment and enables holder-side burning.
 * @custom:author @Tenyokj | https://tenyokj.vercel.app
 */
contract TenjiCoin is ERC20, ERC20Burnable {

    // ===================== ERRORS =====================

    /// @notice One of the required allocation wallets is the zero address
    error ZeroAddress();

    // ===================== CONSTANTS =====================

    /// @notice Immutable total token supply minted at deployment
    uint256 public constant TOTAL_SUPPLY = 167_000_000_000 * 10 ** 18;

    // ===================== CONSTRUCTOR =====================

    /**
     * @notice Deploys the token and distributes the fixed supply
     * @param liquidityWallet Address receiving the liquidity allocation
     * @param teamWallet Address receiving the team allocation
     * @param airdropWallet Address receiving the airdrop allocation
     */
    constructor(
        address liquidityWallet,
        address teamWallet,
        address airdropWallet
    )
        ERC20("TenjiCoin", "TENJI")
    {
        if (
            liquidityWallet == address(0) ||
            teamWallet == address(0) ||
            airdropWallet == address(0)
        ) revert ZeroAddress();

        // 60% - liquidity
        _mint(liquidityWallet, TOTAL_SUPPLY * 60 / 100);

        // 10% - team
        _mint(teamWallet, TOTAL_SUPPLY * 10 / 100);

        // 30% - airdrop
        _mint(airdropWallet, TOTAL_SUPPLY * 30 / 100);
    }
}
