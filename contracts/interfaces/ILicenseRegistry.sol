// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

import {ILicenseChecker} from "./ILicenseChecker.sol";

/**
 * @title ILicenseRegistry
 * @notice Main protocol interface for creating assets, defining license terms, selling access, and querying state.
 * @dev Implemented by the upgradeable registry and consumed by the token contract and external integrators.
 * @custom:version 1.0.1
 */
interface ILicenseRegistry is ILicenseChecker {
    /**
     * @notice Canonical on-chain description of a licensable asset.
     * @param creator The creator or current asset controller.
     * @param metadataURI The metadata URI used as the default token metadata source.
     * @param active Whether the asset is active for sales and validity checks.
     */
    struct Asset {
        address creator;
        string metadataURI;
        bool active;
    }

    /**
     * @notice Commercial and operational terms for a specific license type.
     * @param price The purchase price for a single license.
     * @param paymentToken The ERC20 payment token address, or zero address for native ETH.
     * @param duration The license duration in seconds, or zero for perpetual licenses.
     * @param transferable Whether the ERC-1155 access key can be transferred.
     * @param royaltyBps Royalty basis points used for EIP-2981 quoting.
     * @param active Whether this license type is active for sales and validity checks.
     */
    struct LicenseTerms {
        uint256 price;
        address paymentToken;
        uint64 duration;
        bool transferable;
        uint16 royaltyBps;
        bool active;
    }

    /**
     * @notice One item within a batched purchase request.
     * @param assetId The target asset identifier.
     * @param licenseTypeId The target license type identifier.
     * @param recipient The address that should receive the license. Zero means the caller.
     */
    struct BatchPurchaseItem {
        uint256 assetId;
        uint256 licenseTypeId;
        address recipient;
    }

    /**
     * @notice One item within a batched revoke request.
     * @param user The license holder whose license should be revoked.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     */
    struct BatchRevokeItem {
        address user;
        uint256 assetId;
        uint256 licenseTypeId;
    }

    /**
     * @notice Signed order describing an off-chain authorized sale.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     * @param buyer Optional fixed buyer address. Zero address means any caller may fill the order.
     * @param recipient Optional final recipient of the license. Zero address means the caller receives it.
     * @param paymentToken Payment token override for the order.
     * @param price Signed order price.
     * @param deadline Expiration timestamp for the order. Zero means no deadline.
     * @param salt Unique salt preventing accidental digest collisions.
     */
    struct SignedLicenseOrder {
        uint256 assetId;
        uint256 licenseTypeId;
        address buyer;
        address recipient;
        address paymentToken;
        uint256 price;
        uint64 deadline;
        uint256 salt;
    }

    /// @notice Emitted when a new asset is created.
    event AssetCreated(uint256 indexed assetId, address indexed creator, string metadataURI);
    /// @notice Emitted when an asset metadata URI is updated.
    event AssetMetadataURIUpdated(uint256 indexed assetId, string metadataURI);
    /// @notice Emitted when an asset active flag changes.
    event AssetActiveSet(uint256 indexed assetId, bool active);
    /// @notice Emitted when control of an asset is transferred to a new creator.
    event AssetCreatorTransferred(uint256 indexed assetId, address indexed previousCreator, address indexed newCreator);
    /// @notice Emitted when the ERC-1155 license token contract is linked to the registry.
    event LicenseTokenSet(address indexed token);
    /// @notice Emitted when a new license type is created under an asset.
    event LicenseTypeCreated(
        uint256 indexed assetId,
        uint256 indexed licenseTypeId,
        uint256 indexed tokenId,
        uint256 price,
        address paymentToken,
        uint64 duration,
        bool transferable,
        uint16 royaltyBps
    );
    /// @notice Emitted when license terms are updated.
    event LicenseTermsUpdated(
        uint256 indexed assetId,
        uint256 indexed licenseTypeId,
        uint256 price,
        address paymentToken,
        uint64 duration,
        bool transferable,
        uint16 royaltyBps,
        bool active
    );
    /// @notice Emitted when a license type active flag changes.
    event LicenseTypeActiveSet(uint256 indexed assetId, uint256 indexed licenseTypeId, bool active);
    /// @notice Emitted when a license-specific metadata URI is updated.
    event LicenseMetadataURIUpdated(uint256 indexed assetId, uint256 indexed licenseTypeId, string metadataURI);
    /// @notice Emitted when a license is purchased or granted through one of the purchase flows.
    event LicensePurchased(
        uint256 indexed assetId,
        uint256 indexed licenseTypeId,
        address indexed buyer,
        address receiver,
        uint256 tokenId,
        uint64 expiration,
        address paymentToken,
        uint256 price
    );
    /// @notice Emitted when a license is revoked and its ERC-1155 balance is cleared.
    event LicenseRevoked(
        uint256 indexed assetId,
        uint256 indexed licenseTypeId,
        address indexed user,
        uint256 tokenId
    );
    /// @notice Emitted when a signed order digest is consumed.
    event SignedOrderUsed(bytes32 indexed orderDigest, uint256 indexed assetId, uint256 indexed licenseTypeId);

    /**
     * @notice Creates a new licensable asset.
     * @param metadataURI The metadata URI for the asset and default license metadata.
     * @return assetId The newly created asset identifier.
     */
    function createAsset(string calldata metadataURI) external returns (uint256 assetId);

    /**
     * @notice Creates a license type under an existing asset.
     * @param assetId The parent asset identifier.
     * @param price The purchase price for the license.
     * @param paymentToken The ERC20 payment token, or zero address for ETH.
     * @param duration The license duration in seconds, or zero for perpetual.
     * @param transferable Whether the license token can be transferred.
     * @param royaltyBps The royalty basis points used for EIP-2981 quotes.
     * @return licenseTypeId The newly created license type identifier under the asset.
     */
    function createLicenseType(
        uint256 assetId,
        uint256 price,
        address paymentToken,
        uint64 duration,
        bool transferable,
        uint16 royaltyBps
    ) external returns (uint256 licenseTypeId);

    /**
     * @notice Updates an existing license type.
     * @param assetId The parent asset identifier.
     * @param licenseTypeId The license type identifier.
     * @param newPrice The new license price.
     * @param newPaymentToken The new payment token, or zero address for ETH.
     * @param newDuration The new duration in seconds.
     * @param newTransferable The new transferability flag.
     * @param newRoyaltyBps The new royalty basis points.
     * @param newActive The new active flag.
     */
    function updateLicenseTerms(
        uint256 assetId,
        uint256 licenseTypeId,
        uint256 newPrice,
        address newPaymentToken,
        uint64 newDuration,
        bool newTransferable,
        uint16 newRoyaltyBps,
        bool newActive
    ) external;

    /**
     * @notice Purchases one license directly using the terms stored on-chain.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     */
    function buyLicense(uint256 assetId, uint256 licenseTypeId) external payable;

    /**
     * @notice Purchases multiple licenses in a single transaction.
     * @param items The batched purchase items.
     */
    function buyLicenses(BatchPurchaseItem[] calldata items) external payable;

    /**
     * @notice Fills a creator-signed off-chain order.
     * @param order The signed order payload.
     * @param signature The creator signature over the EIP-712 order digest.
     */
    function buyLicenseWithOrder(SignedLicenseOrder calldata order, bytes calldata signature) external payable;

    /**
     * @notice Links the ERC-1155 token contract to the registry.
     * @param token The upgradeable token proxy address.
     */
    function setLicenseToken(address token) external;

    /**
     * @notice Toggles an asset between active and inactive states.
     * @param assetId The asset identifier.
     * @param active The new active state.
     */
    function setAssetActive(uint256 assetId, bool active) external;

    /**
     * @notice Updates the default metadata URI for an asset.
     * @param assetId The asset identifier.
     * @param metadataURI The new metadata URI.
     */
    function setAssetMetadataURI(uint256 assetId, string calldata metadataURI) external;

    /**
     * @notice Transfers creator control of an asset to a new address.
     * @param assetId The asset identifier.
     * @param newCreator The new creator/controller address.
     */
    function transferAssetCreator(uint256 assetId, address newCreator) external;

    /**
     * @notice Toggles a license type between active and inactive states.
     * @param assetId The parent asset identifier.
     * @param licenseTypeId The license type identifier.
     * @param active The new active state.
     */
    function setLicenseTypeActive(uint256 assetId, uint256 licenseTypeId, bool active) external;

    /**
     * @notice Sets metadata specific to a single license token id.
     * @param assetId The parent asset identifier.
     * @param licenseTypeId The license type identifier.
     * @param metadataURI The new metadata URI for that license token id.
     */
    function setLicenseMetadataURI(uint256 assetId, uint256 licenseTypeId, string calldata metadataURI) external;

    /**
     * @notice Revokes a single issued license.
     * @param user The holder whose license should be revoked.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     */
    function revokeLicense(address user, uint256 assetId, uint256 licenseTypeId) external;

    /**
     * @notice Revokes multiple issued licenses in one transaction.
     * @param items The batched revoke items.
     */
    function revokeLicenses(BatchRevokeItem[] calldata items) external;

    /**
     * @notice Returns the stored asset struct.
     * @param assetId The asset identifier.
     * @return asset The stored asset data.
     */
    function getAsset(uint256 assetId) external view returns (Asset memory asset);

    /**
     * @notice Returns the stored license terms for an asset/license pair.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     * @return terms The stored license terms.
     */
    function getLicenseTerms(uint256 assetId, uint256 licenseTypeId) external view returns (LicenseTerms memory terms);

    /**
     * @notice Checks whether a token id is transferable according to registry state.
     * @param tokenId The ERC-1155 token identifier.
     * @return transferable True when transfers are permitted.
     */
    function isLicenseTransferable(uint256 tokenId) external view returns (bool transferable);

    /**
     * @notice Resolves the metadata URI for a token id.
     * @param tokenId The ERC-1155 token identifier.
     * @return metadataURI The resolved metadata URI.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory metadataURI);

    /**
     * @notice Returns the EIP-2981 royalty receiver and amount for a token sale price.
     * @param tokenId The ERC-1155 token identifier.
     * @param salePrice The secondary sale price.
     * @return receiver The royalty receiver.
     * @return royaltyAmount The royalty amount due.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);

    /**
     * @notice Computes the EIP-712 digest for a signed license order.
     * @param order The signed order payload.
     * @return orderDigest The final typed-data digest.
     */
    function hashSignedLicenseOrder(SignedLicenseOrder calldata order) external view returns (bytes32 orderDigest);

    /**
     * @notice Checks whether a signed order digest has already been used.
     * @param orderDigest The order digest to check.
     * @return used True when the digest has already been consumed.
     */
    function isOrderUsed(bytes32 orderDigest) external view returns (bool used);

    /**
     * @notice Token callback used to move license expiration state during transfers.
     * @param from The previous holder.
     * @param to The new holder.
     * @param tokenId The transferred token identifier.
     * @param amount The transferred amount.
     */
    function syncLicenseTransfer(address from, address to, uint256 tokenId, uint256 amount) external;
}
