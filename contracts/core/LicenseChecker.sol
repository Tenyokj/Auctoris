// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

import {ILicenseChecker} from "../interfaces/ILicenseChecker.sol";
import {InvalidRegistry} from "../utils/Errors.sol";

/**
 * @title LicenseChecker
 * @notice Lightweight helper contract exposing registry read methods through a stable checker entrypoint.
 * @dev Useful for frontends, indexers, or third-party services that want a narrow read-only integration surface.
 * @custom:version 1.0.1
 */
contract LicenseChecker is ILicenseChecker {
    /// @notice Registry contract used as the source of truth for all license state.
    ILicenseChecker public immutable registry;

    /**
     * @notice Creates a new checker bound to a registry.
     * @param registry_ The registry address the checker should read from.
     */
    constructor(address registry_) {
        if (registry_ == address(0)) {
            revert InvalidRegistry(registry_);
        }

        registry = ILicenseChecker(registry_);
    }

    /// @inheritdoc ILicenseChecker
    function getTokenId(uint256 assetId, uint256 licenseTypeId) external view returns (uint256 tokenId) {
        return registry.getTokenId(assetId, licenseTypeId);
    }

    /// @inheritdoc ILicenseChecker
    function hasValidLicense(
        address user,
        uint256 assetId,
        uint256 licenseTypeId
    ) external view returns (bool valid) {
        return registry.hasValidLicense(user, assetId, licenseTypeId);
    }

    /// @inheritdoc ILicenseChecker
    function getExpiration(address user, uint256 tokenId) external view returns (uint64 expiration) {
        return registry.getExpiration(user, tokenId);
    }

    /// @inheritdoc ILicenseChecker
    function getLicenseState(
        address user,
        uint256 assetId,
        uint256 licenseTypeId
    ) external view returns (uint256 tokenId, uint256 balance, uint64 expiration, bool valid) {
        return registry.getLicenseState(user, assetId, licenseTypeId);
    }
}
