// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IDEXTransparentProxyFactory} from "../interfaces/IDEXTransparentProxyFactory.sol";

/**
 * @title DEXTransparentProxyFactory
 * @notice Helper factory to deploy Transparent proxy stack for upgradeable modules.
 * @dev Deploys {ProxyAdmin} + {TransparentUpgradeableProxy} in one call.
 */
contract DEXTransparentProxyFactory is IDEXTransparentProxyFactory {

    /**
     * @notice Deploys a Transparent proxy stack.
     * @param implementation Logic contract.
     * @param adminOwner Owner for ProxyAdmin.
     * @param initData Encoded initializer call for implementation.
     * @return proxyAdmin Address of deployed ProxyAdmin.
     * @return proxy Address of deployed TransparentUpgradeableProxy.
     */
    function deployProxyStack(address implementation, address adminOwner, bytes calldata initData)
        external
        returns (address proxyAdmin, address proxy)
    {
        ProxyAdmin admin = new ProxyAdmin(adminOwner);
        TransparentUpgradeableProxy p =
            new TransparentUpgradeableProxy(implementation, address(admin), initData);

        proxyAdmin = address(admin);
        proxy = address(p);

        emit ProxyStackDeployed(implementation, proxyAdmin, proxy);
    }
}
