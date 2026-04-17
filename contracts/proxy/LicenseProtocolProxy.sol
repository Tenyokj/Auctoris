// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title LicenseProtocolProxy
 * @notice Thin transparent proxy wrapper used for local deployment and testing.
 * @dev The proxy deploys its own ProxyAdmin internally, which keeps upgrade logic out of implementation bytecode.
 * @custom:version 1.0.1
 */
contract LicenseProtocolProxy is TransparentUpgradeableProxy {
    /**
     * @notice Deploys a new transparent proxy and optionally performs initialization.
     * @param implementation The implementation contract address.
     * @param initialOwner The owner of the auto-deployed ProxyAdmin responsible for upgrades.
     * @param data Encoded initializer calldata.
     */
    constructor(
        address implementation,
        address initialOwner,
        bytes memory data
    ) payable TransparentUpgradeableProxy(implementation, initialOwner, data) {}

    /**
     * @notice Returns the ProxyAdmin address controlling upgrades for this proxy.
     * @dev Exposed for local tooling, tests, and deployment scripts.
     * @return admin The ProxyAdmin contract address.
     */
    function proxyAdmin() external view returns (address admin) {
        return _proxyAdmin();
    }

    /**
     * @notice Accepts plain ETH transfers and forwards them through proxy fallback resolution.
     * @dev This silences the Solidity warning about a payable fallback without an explicit receive function.
     */
    receive() external payable {
        _fallback();
    }
}
