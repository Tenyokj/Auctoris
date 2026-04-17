// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

/**
 * @title ILicenseChecker
 * @notice Read-only interface for checking whether a user currently holds a valid license.
 * @dev Intended for external services, frontends, and helper contracts that only need access checks.
 * @custom:version 1.0.1
 */
interface ILicenseChecker {
    /**
     * @notice Resolves the ERC-1155 token identifier for a specific license type under an asset.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier under the asset.
     * @return tokenId The derived ERC-1155 token identifier.
     */
    function getTokenId(uint256 assetId, uint256 licenseTypeId) external view returns (uint256 tokenId);

    /**
     * @notice Checks whether a user currently has a valid license for an asset/license pair.
     * @param user The account being checked.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier under the asset.
     * @return valid True when the user owns the token and the license is active and not expired.
     */
    function hasValidLicense(
        address user,
        uint256 assetId,
        uint256 licenseTypeId
    ) external view returns (bool valid);

    /**
     * @notice Returns the expiration timestamp stored for a user/token pair.
     * @param user The account being checked.
     * @param tokenId The ERC-1155 license token identifier.
     * @return expiration The expiration timestamp, or zero for perpetual licenses.
     */
    function getExpiration(address user, uint256 tokenId) external view returns (uint64 expiration);

    /**
     * @notice Returns the resolved token id, current balance, expiration, and validity in one call.
     * @param user The account being checked.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier under the asset.
     * @return tokenId The resolved ERC-1155 token identifier.
     * @return balance The current ERC-1155 balance for the user and token id.
     * @return expiration The stored expiration timestamp.
     * @return valid True when the user currently has an active and unexpired license.
     */
    function getLicenseState(
        address user,
        uint256 assetId,
        uint256 licenseTypeId
    ) external view returns (uint256 tokenId, uint256 balance, uint64 expiration, bool valid);
}
