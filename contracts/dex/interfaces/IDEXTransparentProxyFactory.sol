// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IDEXTransparentProxyFactory
 * @notice Event interface for transparent proxy stack deployments.
 *
 * @custom:version 1.0.0
 */
interface IDEXTransparentProxyFactory {
    event ProxyStackDeployed(address indexed implementation, address indexed proxyAdmin, address indexed proxy);
}
