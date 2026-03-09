// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockWETH
 * @notice Minimal wrapped ETH implementation for tests.
 * @dev Mints on `deposit` and burns on `withdraw`.
 *
 * @custom:version 1.0.0
 */
contract MockWETH is ERC20("Wrapped Ether", "WETH") {
    /**
     * @notice Emitted on ETH wrap.
     */
    event Deposit(address indexed account, uint256 amount);

    /**
     * @notice Emitted on ETH unwrap.
     */
    event Withdrawal(address indexed account, uint256 amount);

    /**
     * @notice Accepts ETH and wraps to WETH.
     */
    receive() external payable {
        deposit();
    }

    /**
     * @notice Wraps ETH into WETH.
     */
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Unwraps WETH into ETH.
     * @param wad Amount to unwrap.
     */
    function withdraw(uint256 wad) external {
        _burn(msg.sender, wad);
        (bool ok, ) = msg.sender.call{value: wad}("");
        require(ok, "ETH_TRANSFER_FAILED");
        emit Withdrawal(msg.sender, wad);
    }
}

