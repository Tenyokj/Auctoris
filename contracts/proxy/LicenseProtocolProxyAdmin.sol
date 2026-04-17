// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title LicenseProtocolProxyAdmin
 * @notice Thin ProxyAdmin wrapper kept in-repo so local tooling has a stable artifact and ABI for upgrades.
 * @dev This contract is not deployed directly by the protocol wrapper, but it matches the OpenZeppelin ProxyAdmin ABI.
 * @custom:version 1.0.1
 */
contract LicenseProtocolProxyAdmin is ProxyAdmin {
    /**
     * @notice Deploys a ProxyAdmin owned by `initialOwner`.
     * @param initialOwner The account allowed to execute proxy upgrades.
     */
    constructor(address initialOwner) ProxyAdmin(initialOwner) {}
}
