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
    /// @notice Fixed liquidity allocation minted to the liquidity wallet
    uint256 public constant LIQUIDITY_ALLOCATION = 60_000_000_000 * 10 ** 18;
    /// @notice Fixed team allocation minted to the team wallet
    uint256 public constant TEAM_ALLOCATION = 20_000_000_000 * 10 ** 18;
    /// @notice Fixed airdrop allocation minted to the airdrop contract
    uint256 public constant AIRDROP_ALLOCATION = 20_000_000_000 * 10 ** 18;
    /// @notice Remaining supply reserved for marketing, future liquidity, and ecosystem ops
    uint256 public constant RESERVE_ALLOCATION =
        TOTAL_SUPPLY - LIQUIDITY_ALLOCATION - TEAM_ALLOCATION - AIRDROP_ALLOCATION;

    // ===================== CONSTRUCTOR =====================

    /**
     * @notice Deploys the token and distributes the fixed supply
     * @param liquidityWallet Address receiving the liquidity allocation
     * @param teamWallet Address receiving the team allocation
     * @param airdropWallet Address receiving the airdrop allocation
     * @param reserveWallet Address receiving the reserve allocation
     */
    constructor(
        address liquidityWallet,
        address teamWallet,
        address airdropWallet,
        address reserveWallet
    )
        ERC20("TenjiCoin", "TENJI")
    {
        if (
            liquidityWallet == address(0) ||
            teamWallet == address(0) ||
            airdropWallet == address(0) ||
            reserveWallet == address(0)
        ) revert ZeroAddress();

        // Fixed launch liquidity allocation.
        _mint(liquidityWallet, LIQUIDITY_ALLOCATION);

        // Fixed team allocation.
        _mint(teamWallet, TEAM_ALLOCATION);

        // Fixed airdrop allocation minted directly to the airdrop contract.
        _mint(airdropWallet, AIRDROP_ALLOCATION);

        // Remaining reserve for marketing, future liquidity, and ecosystem operations.
        _mint(reserveWallet, RESERVE_ALLOCATION);
    }
}
