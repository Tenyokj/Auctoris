// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

/// @notice Thrown when an admin-only action is attempted by a non-admin account.
/// @param caller The account that attempted the restricted action.
error UnauthorizedAdmin(address caller);

/// @notice Thrown when an asset-scoped administrative action is attempted by an unauthorized account.
/// @param assetId The asset whose permissions were checked.
/// @param caller The account that attempted the restricted action.
error UnauthorizedAssetController(uint256 assetId, address caller);

/// @notice Thrown when an asset identifier does not exist in storage.
/// @param assetId The missing asset identifier.
error AssetNotFound(uint256 assetId);

/// @notice Thrown when an asset exists but is currently inactive.
/// @param assetId The inactive asset identifier.
error AssetInactive(uint256 assetId);

/// @notice Thrown when a caller is not the creator currently assigned to an asset.
/// @param assetId The asset whose ownership was checked.
/// @param caller The unauthorized caller.
error NotAssetCreator(uint256 assetId, address caller);

/// @notice Thrown when a license type identifier does not exist under a given asset.
/// @param assetId The parent asset identifier.
/// @param licenseTypeId The missing license type identifier.
error LicenseTypeNotFound(uint256 assetId, uint256 licenseTypeId);

/// @notice Thrown when a license type exists but is currently inactive.
/// @param assetId The parent asset identifier.
/// @param licenseTypeId The inactive license type identifier.
error LicenseTypeInactive(uint256 assetId, uint256 licenseTypeId);

/// @notice Thrown when royalty basis points exceed the supported 100% cap.
/// @param royaltyBps The invalid royalty value in basis points.
error InvalidRoyaltyBps(uint16 royaltyBps);

/// @notice Thrown when the supplied payment value does not match the expected amount.
/// @param expected The expected payment amount.
/// @param received The actual payment amount received by the contract.
error IncorrectPayment(uint256 expected, uint256 received);

/// @notice Thrown when native ETH is sent to a function that expects ERC20 payment only.
/// @param received The unexpected native value attached to the call.
error UnexpectedNativePayment(uint256 received);

/// @notice Thrown when the license token contract has already been linked and cannot be changed again.
/// @param token The already linked token address.
error LicenseTokenAlreadySet(address token);

/// @notice Thrown when an invalid token contract address is supplied.
/// @param token The invalid token address.
error InvalidLicenseToken(address token);

/// @notice Thrown when a non-contract address is supplied as an ERC20 payment token.
/// @param token The invalid ERC20 token address.
error InvalidPaymentToken(address token);

/// @notice Thrown when a registry action depends on a linked license token but none has been configured yet.
error LicenseTokenNotSet();

/// @notice Thrown when a token-only callback is invoked by a caller other than the configured license token contract.
/// @param caller The unauthorized caller.
error UnauthorizedLicenseToken(address caller);

/// @notice Thrown when a zero address or otherwise invalid creator address is supplied.
/// @param creator The invalid creator address.
error InvalidCreator(address creator);

/// @notice Thrown when a zero address or otherwise invalid license holder is supplied.
/// @param user The invalid holder address.
error InvalidLicenseHolder(address user);

/// @notice Thrown when a zero address is supplied where a recipient is required.
/// @param recipient The invalid recipient address.
error InvalidRecipient(address recipient);

/// @notice Thrown when forwarding proceeds to the creator fails.
/// @param creator The intended payout recipient.
/// @param value The payment amount that could not be forwarded.
error CreatorPaymentFailed(address creator, uint256 value);

/// @notice Thrown when an expiration calculation would overflow the supported uint64 timestamp range.
error ExpirationOverflow();

/// @notice Thrown when a transfer tries to move anything other than a single-license balance unit.
/// @param amount The unsupported transfer amount.
error UnsupportedTransferAmount(uint256 amount);

/// @notice Thrown when a batch operation is submitted with zero items.
error EmptyBatch();

/// @notice Thrown when a signed order is past its validity deadline.
/// @param deadline The expired order deadline.
error OrderExpired(uint64 deadline);

/// @notice Thrown when a signed order digest has already been consumed.
/// @param orderDigest The digest that was already used.
error OrderAlreadyUsed(bytes32 orderDigest);

/// @notice Thrown when the order locks execution to a different buyer than the current caller.
/// @param expectedBuyer The buyer encoded into the signed order.
/// @param actualBuyer The caller attempting to fill the order.
error InvalidOrderBuyer(address expectedBuyer, address actualBuyer);

/// @notice Thrown when a signed order cannot be validated against the creator signature.
/// @param orderDigest The invalid or unverified order digest.
error InvalidOrderSignature(bytes32 orderDigest);

/// @notice Thrown when a non-reentrant function is entered while already executing.
error ReentrantCall();

/// @notice Thrown when a registry-dependent contract is initialized with a zero registry address.
/// @param registry The invalid registry address.
error InvalidRegistry(address registry);

/// @notice Thrown when a registry-only action is attempted by a caller other than the linked registry.
/// @param caller The unauthorized caller.
error UnauthorizedRegistry(address caller);

/// @notice Thrown when a non-transferable license token is transferred.
/// @param tokenId The token identifier that cannot be transferred.
error TransferNotAllowed(uint256 tokenId);

/// @notice Thrown when a recipient already owns the same license token and cannot receive a duplicate balance.
/// @param holder The recipient that already owns the token.
/// @param tokenId The duplicate token identifier.
error DuplicateLicenseHolder(address holder, uint256 tokenId);
