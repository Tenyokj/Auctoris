// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ILicenseRegistry} from "../interfaces/ILicenseRegistry.sol";
import {LicenseTokenUpgradeable} from "./LicenseTokenUpgradeable.sol";
import "../utils/Errors.sol";

/**
 * @title LicenseRegistryUpgradeable
 * @notice Main upgradeable registry for on-chain license issuance, payment settlement, signed orders, and access checks.
 * @dev This contract is the single source of truth for assets, license types, expirations, transfer policy, and royalty quoting.
 * @dev Upgradeable, transparent-proxy compatible, EIP-712 enabled
 * @custom:version 1.0.1
 */
contract LicenseRegistryUpgradeable is Initializable, ILicenseRegistry, OwnableUpgradeable, EIP712Upgradeable {
    using SafeERC20 for IERC20;

    /// @dev Typehash for creator-signed off-chain license orders.
    bytes32 private constant SIGNED_LICENSE_ORDER_TYPEHASH =
        keccak256(
            "SignedLicenseOrder(uint256 assetId,uint256 licenseTypeId,address buyer,address recipient,address paymentToken,uint256 price,uint64 deadline,uint256 salt)"
        );

    /// @dev Local non-reentrancy sentinel value for the idle state.
    uint256 private constant NOT_ENTERED = 1;
    /// @dev Local non-reentrancy sentinel value for the entered state.
    uint256 private constant ENTERED = 2;

    /// @notice Monotonic asset id counter. Starts at 1 so zero can safely represent “not initialized”.
    uint256 public nextAssetId;
    /// @notice Stored asset records keyed by `assetId`.
    mapping(uint256 => Asset) private assets;
    /// @notice Per-asset counter tracking the next license type identifier.
    mapping(uint256 => uint256) private nextLicenseTypeId;
    /// @notice Stored license terms keyed by `assetId => licenseTypeId`.
    mapping(uint256 => mapping(uint256 => LicenseTerms)) private licenseTypes;
    /// @notice ERC-1155 token ids keyed by `assetId => licenseTypeId`.
    mapping(uint256 => mapping(uint256 => uint256)) private tokenIds;
    /// @notice Expiration timestamps keyed by `holder => tokenId`. Zero means perpetual.
    mapping(address => mapping(uint256 => uint64)) private expirations;
    /// @notice Linked ERC-1155 token proxy that stores balances.
    address public licenseToken;

    /// @dev Optional license-specific metadata URI overrides keyed by token id.
    mapping(uint256 => string) private _licenseMetadataURIs;
    /// @dev Replay protection for signed license orders.
    mapping(bytes32 => bool) private _usedOrderDigests;
    /// @dev Local reentrancy status for purchase flows.
    uint256 private _reentrancyStatus;

    /**
     * @dev Restricts a function to the registry owner.
     */
    modifier onlyAdmin() {
        if (msg.sender != owner()) {
            revert UnauthorizedAdmin(msg.sender);
        }
        _;
    }

    /**
     * @dev Restricts a function to the current creator/controller of an asset.
     * @param assetId The asset whose creator ownership is checked.
     */
    modifier onlyAssetCreator(uint256 assetId) {
        Asset storage asset = assets[assetId];

        if (asset.creator == address(0)) {
            revert AssetNotFound(assetId);
        }
        if (asset.creator != msg.sender) {
            revert NotAssetCreator(assetId, msg.sender);
        }

        _;
    }

    /**
     * @dev Restricts token callback functions to the linked ERC-1155 token proxy.
     */
    modifier onlyLicenseToken() {
        if (msg.sender != licenseToken) {
            revert UnauthorizedLicenseToken(msg.sender);
        }
        _;
    }

    /**
     * @dev Restricts asset-scoped administrative actions to either the asset creator or the registry owner.
     * @param assetId The asset whose controller permissions are checked.
     */
    modifier onlyAssetController(uint256 assetId) {
        _checkAssetController(assetId);
        _;
    }

    /**
     * @dev Prevents reentrant purchase execution.
     */
    modifier nonReentrant() {
        if (_reentrancyStatus == ENTERED) {
            revert ReentrantCall();
        }

        _reentrancyStatus = ENTERED;
        _;
        _reentrancyStatus = NOT_ENTERED;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the registry proxy.
     * @param initialOwner The owner authorized to perform protocol-level administration inside the registry.
     */
    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __EIP712_init("Auctoris Licensing Authority", "1");

        nextAssetId = 1;
        _reentrancyStatus = NOT_ENTERED;
    }

    // ---------------------------------------------------------------------
    // Asset management
    // ---------------------------------------------------------------------

    /// @inheritdoc ILicenseRegistry
    function createAsset(string calldata metadataURI) external returns (uint256 assetId) {
        assetId = nextAssetId;

        assets[assetId] = Asset({creator: msg.sender, metadataURI: metadataURI, active: true});

        unchecked {
            nextAssetId = assetId + 1;
        }

        emit AssetCreated(assetId, msg.sender, metadataURI);
    }

    /// @inheritdoc ILicenseRegistry
    function setAssetActive(uint256 assetId, bool active) external onlyAssetCreator(assetId) {
        assets[assetId].active = active;

        emit AssetActiveSet(assetId, active);
    }

    /// @inheritdoc ILicenseRegistry
    function setAssetMetadataURI(uint256 assetId, string calldata metadataURI) external onlyAssetCreator(assetId) {
        assets[assetId].metadataURI = metadataURI;

        emit AssetMetadataURIUpdated(assetId, metadataURI);
    }

    /// @inheritdoc ILicenseRegistry
    function transferAssetCreator(uint256 assetId, address newCreator) external onlyAssetCreator(assetId) {
        if (newCreator == address(0)) {
            revert InvalidCreator(newCreator);
        }

        address previousCreator = assets[assetId].creator;
        assets[assetId].creator = newCreator;

        emit AssetCreatorTransferred(assetId, previousCreator, newCreator);
    }

    // ---------------------------------------------------------------------
    // License type management
    // ---------------------------------------------------------------------

    /// @inheritdoc ILicenseRegistry
    function createLicenseType(
        uint256 assetId,
        uint256 price,
        address paymentToken,
        uint64 duration,
        bool transferable,
        uint16 royaltyBps
    ) external onlyAssetCreator(assetId) returns (uint256 licenseTypeId) {
        _validateRoyalty(royaltyBps);
        _validatePaymentToken(paymentToken);

        licenseTypeId = nextLicenseTypeId[assetId];

        LicenseTerms storage terms = licenseTypes[assetId][licenseTypeId];
        terms.price = price;
        terms.paymentToken = paymentToken;
        terms.duration = duration;
        terms.transferable = transferable;
        terms.royaltyBps = royaltyBps;
        terms.active = true;

        uint256 tokenId = _encodeTokenId(assetId, licenseTypeId);
        tokenIds[assetId][licenseTypeId] = tokenId;

        unchecked {
            nextLicenseTypeId[assetId] = licenseTypeId + 1;
        }

        emit LicenseTypeCreated(
            assetId,
            licenseTypeId,
            tokenId,
            price,
            paymentToken,
            duration,
            transferable,
            royaltyBps
        );
    }

    /// @inheritdoc ILicenseRegistry
    function updateLicenseTerms(
        uint256 assetId,
        uint256 licenseTypeId,
        uint256 newPrice,
        address newPaymentToken,
        uint64 newDuration,
        bool newTransferable,
        uint16 newRoyaltyBps,
        bool newActive
    ) external onlyAssetCreator(assetId) {
        if (!_licenseTypeExists(assetId, licenseTypeId)) {
            revert LicenseTypeNotFound(assetId, licenseTypeId);
        }

        _validateRoyalty(newRoyaltyBps);
        _validatePaymentToken(newPaymentToken);

        LicenseTerms storage terms = licenseTypes[assetId][licenseTypeId];
        terms.price = newPrice;
        terms.paymentToken = newPaymentToken;
        terms.duration = newDuration;
        terms.transferable = newTransferable;
        terms.royaltyBps = newRoyaltyBps;
        terms.active = newActive;

        emit LicenseTermsUpdated(
            assetId,
            licenseTypeId,
            newPrice,
            newPaymentToken,
            newDuration,
            newTransferable,
            newRoyaltyBps,
            newActive
        );
    }

    /// @inheritdoc ILicenseRegistry
    function setLicenseTypeActive(
        uint256 assetId,
        uint256 licenseTypeId,
        bool active
    ) external onlyAssetCreator(assetId) {
        if (!_licenseTypeExists(assetId, licenseTypeId)) {
            revert LicenseTypeNotFound(assetId, licenseTypeId);
        }

        licenseTypes[assetId][licenseTypeId].active = active;

        emit LicenseTypeActiveSet(assetId, licenseTypeId, active);
    }

    /// @inheritdoc ILicenseRegistry
    function setLicenseMetadataURI(
        uint256 assetId,
        uint256 licenseTypeId,
        string calldata metadataURI
    ) external onlyAssetCreator(assetId) {
        uint256 tokenId = getTokenId(assetId, licenseTypeId);
        _licenseMetadataURIs[tokenId] = metadataURI;

        emit LicenseMetadataURIUpdated(assetId, licenseTypeId, metadataURI);
    }

    // ---------------------------------------------------------------------
    // Purchase flows
    // ---------------------------------------------------------------------

    /// @inheritdoc ILicenseRegistry
    function buyLicense(uint256 assetId, uint256 licenseTypeId) external payable nonReentrant {
        PurchaseContext memory context = _getActivePurchaseContext(assetId, licenseTypeId);

        _validateSinglePayment(context.terms.paymentToken, context.terms.price, msg.value);
        _executePurchase(msg.sender, msg.sender, context, context.terms.paymentToken, context.terms.price);
    }

    /// @inheritdoc ILicenseRegistry
    function buyLicenses(BatchPurchaseItem[] calldata items) external payable nonReentrant {
        uint256 itemsLength = items.length;
        if (itemsLength == 0) {
            revert EmptyBatch();
        }

        uint256 expectedNativeValue;
        for (uint256 i = 0; i < itemsLength; ++i) {
            PurchaseContext memory context = _getActivePurchaseContext(items[i].assetId, items[i].licenseTypeId);
            if (context.terms.paymentToken == address(0)) {
                expectedNativeValue += context.terms.price;
            }
        }

        if (msg.value != expectedNativeValue) {
            revert IncorrectPayment(expectedNativeValue, msg.value);
        }

        for (uint256 i = 0; i < itemsLength; ++i) {
            PurchaseContext memory context = _getActivePurchaseContext(items[i].assetId, items[i].licenseTypeId);
            address recipient = items[i].recipient == address(0) ? msg.sender : items[i].recipient;

            _executePurchase(msg.sender, recipient, context, context.terms.paymentToken, context.terms.price);
        }
    }

    /// @inheritdoc ILicenseRegistry
    function buyLicenseWithOrder(
        SignedLicenseOrder calldata order,
        bytes calldata signature
    ) external payable nonReentrant {
        PurchaseContext memory context = _getActivePurchaseContext(order.assetId, order.licenseTypeId);
        bytes32 orderDigest = hashSignedLicenseOrder(order);

        if (_usedOrderDigests[orderDigest]) {
            revert OrderAlreadyUsed(orderDigest);
        }
        if (order.deadline != 0 && order.deadline < block.timestamp) {
            revert OrderExpired(order.deadline);
        }
        if (order.buyer != address(0) && order.buyer != msg.sender) {
            revert InvalidOrderBuyer(order.buyer, msg.sender);
        }

        _validatePaymentToken(order.paymentToken);

        if (!SignatureChecker.isValidSignatureNowCalldata(context.creator, orderDigest, signature)) {
            revert InvalidOrderSignature(orderDigest);
        }

        _usedOrderDigests[orderDigest] = true;

        address recipient = order.recipient == address(0) ? msg.sender : order.recipient;
        _validateSinglePayment(order.paymentToken, order.price, msg.value);
        _executePurchase(msg.sender, recipient, context, order.paymentToken, order.price);

        emit SignedOrderUsed(orderDigest, order.assetId, order.licenseTypeId);
    }

    // ---------------------------------------------------------------------
    // Token linkage and revoke flows
    // ---------------------------------------------------------------------

    /// @inheritdoc ILicenseRegistry
    function setLicenseToken(address token) external onlyAdmin {
        if (token == address(0)) {
            revert InvalidLicenseToken(token);
        }
        if (licenseToken != address(0)) {
            revert LicenseTokenAlreadySet(licenseToken);
        }

        licenseToken = token;

        emit LicenseTokenSet(token);
    }

    /// @inheritdoc ILicenseRegistry
    function revokeLicense(address user, uint256 assetId, uint256 licenseTypeId) external onlyAssetController(assetId) {
        _revokeLicense(user, assetId, licenseTypeId);
    }

    /// @inheritdoc ILicenseRegistry
    function revokeLicenses(BatchRevokeItem[] calldata items) external {
        uint256 itemsLength = items.length;
        if (itemsLength == 0) {
            revert EmptyBatch();
        }

        for (uint256 i = 0; i < itemsLength; ++i) {
            _checkAssetController(items[i].assetId);
            _revokeLicense(items[i].user, items[i].assetId, items[i].licenseTypeId);
        }
    }

    /// @inheritdoc ILicenseRegistry
    function syncLicenseTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external onlyLicenseToken {
        if (amount != 1) {
            revert UnsupportedTransferAmount(amount);
        }

        expirations[to][tokenId] = expirations[from][tokenId];
        delete expirations[from][tokenId];
    }

    // ---------------------------------------------------------------------
    // Read API
    // ---------------------------------------------------------------------

    /**
     * @notice Checks whether a user currently holds a valid license.
     * @param user The account being checked.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     * @return valid True when the user owns the license token and it is active and unexpired.
     */
    function hasValidLicense(
        address user,
        uint256 assetId,
        uint256 licenseTypeId
    ) public view returns (bool valid) {
        if (!_licenseTypeExists(assetId, licenseTypeId)) {
            return false;
        }

        Asset storage asset = assets[assetId];
        if (asset.creator == address(0) || !asset.active) {
            return false;
        }

        LicenseTerms storage terms = licenseTypes[assetId][licenseTypeId];
        if (!terms.active) {
            return false;
        }

        address token = licenseToken;
        if (token == address(0)) {
            return false;
        }

        uint256 tokenId = tokenIds[assetId][licenseTypeId];
        if (IERC1155(token).balanceOf(user, tokenId) == 0) {
            return false;
        }

        uint64 expiration = expirations[user][tokenId];
        return expiration == 0 || expiration > block.timestamp;
    }

    /**
     * @notice Resolves the ERC-1155 token identifier for an asset/license pair.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     * @return tokenId The packed ERC-1155 token identifier.
     */
    function getTokenId(uint256 assetId, uint256 licenseTypeId) public view returns (uint256 tokenId) {
        if (!_licenseTypeExists(assetId, licenseTypeId)) {
            revert LicenseTypeNotFound(assetId, licenseTypeId);
        }

        return tokenIds[assetId][licenseTypeId];
    }

    /**
     * @notice Returns the stored expiration timestamp for a user/token pair.
     * @param user The account being checked.
     * @param tokenId The ERC-1155 token identifier.
     * @return expiration The stored expiration timestamp, or zero for perpetual licenses.
     */
    function getExpiration(address user, uint256 tokenId) external view returns (uint64 expiration) {
        return expirations[user][tokenId];
    }

    /**
     * @notice Returns token id, balance, expiration, and validity in a single call.
     * @param user The account being checked.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     * @return tokenId The packed ERC-1155 token identifier.
     * @return balance The current balance held by the user.
     * @return expiration The stored expiration timestamp.
     * @return valid True when the license is active and currently valid.
     */
    function getLicenseState(
        address user,
        uint256 assetId,
        uint256 licenseTypeId
    ) external view returns (uint256 tokenId, uint256 balance, uint64 expiration, bool valid) {
        tokenId = getTokenId(assetId, licenseTypeId);

        if (licenseToken != address(0)) {
            balance = IERC1155(licenseToken).balanceOf(user, tokenId);
        }

        expiration = expirations[user][tokenId];
        valid = hasValidLicense(user, assetId, licenseTypeId);
    }

    /// @inheritdoc ILicenseRegistry
    function getAsset(uint256 assetId) external view returns (Asset memory asset) {
        asset = assets[assetId];
        if (asset.creator == address(0)) {
            revert AssetNotFound(assetId);
        }
    }

    /// @inheritdoc ILicenseRegistry
    function getLicenseTerms(
        uint256 assetId,
        uint256 licenseTypeId
    ) external view returns (LicenseTerms memory terms) {
        if (!_licenseTypeExists(assetId, licenseTypeId)) {
            revert LicenseTypeNotFound(assetId, licenseTypeId);
        }

        terms = licenseTypes[assetId][licenseTypeId];
    }

    /// @inheritdoc ILicenseRegistry
    function isLicenseTransferable(uint256 tokenId) external view returns (bool transferable) {
        (uint256 assetId, uint256 licenseTypeId) = _decodeTokenId(tokenId);

        if (!_licenseTypeExists(assetId, licenseTypeId)) {
            return false;
        }

        return licenseTypes[assetId][licenseTypeId].transferable;
    }

    /// @inheritdoc ILicenseRegistry
    function tokenURI(uint256 tokenId) external view returns (string memory metadataURI) {
        (uint256 assetId, uint256 licenseTypeId) = _decodeTokenId(tokenId);

        if (!_licenseTypeExists(assetId, licenseTypeId)) {
            revert LicenseTypeNotFound(assetId, licenseTypeId);
        }

        string memory customURI = _licenseMetadataURIs[tokenId];
        if (bytes(customURI).length != 0) {
            return customURI;
        }

        return assets[assetId].metadataURI;
    }

    /// @inheritdoc ILicenseRegistry
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount) {
        (uint256 assetId, uint256 licenseTypeId) = _decodeTokenId(tokenId);

        if (!_licenseTypeExists(assetId, licenseTypeId)) {
            return (address(0), 0);
        }

        receiver = assets[assetId].creator;
        royaltyAmount = (salePrice * licenseTypes[assetId][licenseTypeId].royaltyBps) / 10_000;
    }

    /// @inheritdoc ILicenseRegistry
    function hashSignedLicenseOrder(SignedLicenseOrder calldata order) public view returns (bytes32 orderDigest) {
        bytes32 structHash = keccak256(
            abi.encode(
                SIGNED_LICENSE_ORDER_TYPEHASH,
                order.assetId,
                order.licenseTypeId,
                order.buyer,
                order.recipient,
                order.paymentToken,
                order.price,
                order.deadline,
                order.salt
            )
        );

        return _hashTypedDataV4(structHash);
    }

    /// @inheritdoc ILicenseRegistry
    function isOrderUsed(bytes32 orderDigest) external view returns (bool used) {
        return _usedOrderDigests[orderDigest];
    }

    // ---------------------------------------------------------------------
    // Internal purchase engine
    // ---------------------------------------------------------------------

    /**
     * @notice Minimal context object shared across all purchase entrypoints.
     * @param terms The resolved on-chain license terms.
     * @param tokenId The ERC-1155 token identifier.
     * @param creator The current asset creator/payout recipient.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     */
    struct PurchaseContext {
        LicenseTerms terms;
        uint256 tokenId;
        address creator;
        uint256 assetId;
        uint256 licenseTypeId;
    }

    /**
     * @notice Performs all shared settlement and issuance work for a purchase path.
     * @param payer The account funding the purchase.
     * @param recipient The account that will receive the license.
     * @param context The resolved purchase context.
     * @param paymentToken The payment token to settle with.
     * @param price The price to settle.
     */
    function _executePurchase(
        address payer,
        address recipient,
        PurchaseContext memory context,
        address paymentToken,
        uint256 price
    ) internal {
        if (recipient == address(0)) {
            revert InvalidRecipient(recipient);
        }

        _settlePayment(payer, context.creator, paymentToken, price);
        uint64 expiration = _grantLicense(recipient, context.tokenId, context.terms.duration);

        emit LicensePurchased(
            context.assetId,
            context.licenseTypeId,
            payer,
            recipient,
            context.tokenId,
            expiration,
            paymentToken,
            price
        );
    }

    /**
     * @notice Grants or renews a license for a recipient.
     * @param recipient The account receiving the license.
     * @param tokenId The ERC-1155 token identifier.
     * @param duration The duration in seconds, or zero for perpetual.
     * @return expiration The resulting expiration timestamp.
     */
    function _grantLicense(address recipient, uint256 tokenId, uint64 duration) internal returns (uint64 expiration) {
        address token = licenseToken;
        if (token == address(0)) {
            revert LicenseTokenNotSet();
        }

        uint256 currentBalance = IERC1155(token).balanceOf(recipient, tokenId);
        if (currentBalance == 0) {
            LicenseTokenUpgradeable(token).mint(recipient, tokenId, 1);
        }

        if (duration != 0) {
            uint256 baseTimestamp = block.timestamp;
            uint64 currentExpiration = expirations[recipient][tokenId];
            if (currentExpiration > block.timestamp) {
                baseTimestamp = currentExpiration;
            }

            uint256 nextExpiration = baseTimestamp + duration;
            if (nextExpiration > type(uint64).max) {
                revert ExpirationOverflow();
            }

            expiration = uint64(nextExpiration);
        }

        expirations[recipient][tokenId] = expiration;
    }

    /**
     * @notice Settles payment from the payer to the creator using ETH or ERC20.
     * @param payer The paying account.
     * @param creator The payout recipient.
     * @param paymentToken The ERC20 token address, or zero address for ETH.
     * @param price The payment amount.
     */
    function _settlePayment(address payer, address creator, address paymentToken, uint256 price) internal {
        if (price == 0) {
            return;
        }

        if (paymentToken == address(0)) {
            (bool success, ) = creator.call{value: price}("");
            if (!success) {
                revert CreatorPaymentFailed(creator, price);
            }
        } else {
            IERC20(paymentToken).safeTransferFrom(payer, creator, price);
        }
    }

    /**
     * @notice Validates a single purchase payment payload.
     * @param paymentToken The payment token expected by the flow.
     * @param price The required price.
     * @param nativeValue The native ETH attached to the call.
     */
    function _validateSinglePayment(address paymentToken, uint256 price, uint256 nativeValue) internal pure {
        if (paymentToken == address(0)) {
            if (nativeValue != price) {
                revert IncorrectPayment(price, nativeValue);
            }
        } else if (nativeValue != 0) {
            revert UnexpectedNativePayment(nativeValue);
        }
    }

    /**
     * @notice Resolves and validates the current sale context for an asset/license pair.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     * @return context The fully resolved purchase context.
     */
    function _getActivePurchaseContext(
        uint256 assetId,
        uint256 licenseTypeId
    ) internal view returns (PurchaseContext memory context) {
        Asset storage asset = assets[assetId];

        if (asset.creator == address(0)) {
            revert AssetNotFound(assetId);
        }
        if (!asset.active) {
            revert AssetInactive(assetId);
        }
        if (!_licenseTypeExists(assetId, licenseTypeId)) {
            revert LicenseTypeNotFound(assetId, licenseTypeId);
        }

        LicenseTerms storage terms = licenseTypes[assetId][licenseTypeId];
        if (!terms.active) {
            revert LicenseTypeInactive(assetId, licenseTypeId);
        }

        context = PurchaseContext({
            terms: terms,
            tokenId: tokenIds[assetId][licenseTypeId],
            creator: asset.creator,
            assetId: assetId,
            licenseTypeId: licenseTypeId
        });
    }

    /**
     * @notice Revokes a single issued license and clears its expiration state.
     * @param user The holder whose license should be removed.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     */
    function _revokeLicense(address user, uint256 assetId, uint256 licenseTypeId) internal {
        if (user == address(0)) {
            revert InvalidLicenseHolder(user);
        }

        address token = licenseToken;
        if (token == address(0)) {
            revert LicenseTokenNotSet();
        }

        uint256 tokenId = getTokenId(assetId, licenseTypeId);
        uint256 balance = IERC1155(token).balanceOf(user, tokenId);

        if (balance != 0) {
            LicenseTokenUpgradeable(token).burn(user, tokenId, balance);
        }

        delete expirations[user][tokenId];

        emit LicenseRevoked(assetId, licenseTypeId, user, tokenId);
    }

    // ---------------------------------------------------------------------
    // Internal validation and helpers
    // ---------------------------------------------------------------------

    /**
     * @notice Checks whether a caller can administrate an asset.
     * @param assetId The asset identifier.
     */
    function _checkAssetController(uint256 assetId) internal view {
        Asset storage asset = assets[assetId];

        if (asset.creator == address(0)) {
            revert AssetNotFound(assetId);
        }
        if (msg.sender != asset.creator && msg.sender != owner()) {
            revert UnauthorizedAssetController(assetId, msg.sender);
        }
    }

    /**
     * @notice Validates royalty basis points against the protocol cap.
     * @param royaltyBps The royalty basis points to validate.
     */
    function _validateRoyalty(uint16 royaltyBps) internal pure {
        if (royaltyBps > 10_000) {
            revert InvalidRoyaltyBps(royaltyBps);
        }
    }

    /**
     * @notice Validates that a payment token is either native ETH or a deployed ERC20 contract.
     * @param paymentToken The payment token address.
     */
    function _validatePaymentToken(address paymentToken) internal view {
        if (paymentToken != address(0) && paymentToken.code.length == 0) {
            revert InvalidPaymentToken(paymentToken);
        }
    }

    /**
     * @notice Checks whether a license type exists under an asset.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     * @return exists True when the license type has been created.
     */
    function _licenseTypeExists(uint256 assetId, uint256 licenseTypeId) internal view returns (bool exists) {
        return assets[assetId].creator != address(0) && licenseTypeId < nextLicenseTypeId[assetId];
    }

    /**
     * @notice Encodes an asset/license pair into one ERC-1155 token identifier.
     * @param assetId The asset identifier.
     * @param licenseTypeId The license type identifier.
     * @return tokenId The packed ERC-1155 token identifier.
     */
    function _encodeTokenId(uint256 assetId, uint256 licenseTypeId) internal pure returns (uint256 tokenId) {
        return (assetId << 128) | licenseTypeId;
    }

    /**
     * @notice Decodes an ERC-1155 token identifier into its asset/license components.
     * @param tokenId The packed ERC-1155 token identifier.
     * @return assetId The decoded asset identifier.
     * @return licenseTypeId The decoded license type identifier.
     */
    function _decodeTokenId(uint256 tokenId) internal pure returns (uint256 assetId, uint256 licenseTypeId) {
        assetId = tokenId >> 128;
        licenseTypeId = uint128(tokenId);
    }

}
