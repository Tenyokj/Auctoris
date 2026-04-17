// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.28;

import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ILicenseRegistry} from "../interfaces/ILicenseRegistry.sol";
import {
    DuplicateLicenseHolder,
    InvalidRegistry,
    TransferNotAllowed,
    UnauthorizedRegistry
} from "../utils/Errors.sol";

/**
 * @title LicenseTokenUpgradeable
 * @notice Upgradeable ERC-1155 contract that holds license access keys.
 * @dev The token is intentionally thin: all commercial logic, transfer policy, expiration, and royalty policy live in the registry.
 * @dev Upgradeable, transparent-proxy compatible
 * @custom:version 1.0.1
 */
contract LicenseTokenUpgradeable is Initializable, ERC1155Upgradeable, IERC2981 {
    /// @notice Registry contract that controls minting, burning, transfer policy, metadata, and royalty resolution.
    address public registry;

    /**
     * @notice Restricts a function so it can only be called by the linked registry.
     */
    modifier onlyRegistry() {
        if (msg.sender != registry) {
            revert UnauthorizedRegistry(msg.sender);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the token proxy.
     * @param registry_ The registry contract that will control token issuance and policy.
     */
    function initialize(address registry_) external initializer {
        if (registry_ == address(0)) {
            revert InvalidRegistry(registry_);
        }

        __ERC1155_init("");
        registry = registry_;
    }

    /**
     * @notice Returns the metadata URI for a specific license token.
     * @dev Metadata resolution is delegated to the registry so all token metadata policy stays centralized.
     * @param tokenId The ERC-1155 token identifier.
     * @return metadataURI The resolved metadata URI.
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory metadataURI) {
        return ILicenseRegistry(registry).tokenURI(tokenId);
    }

    /**
     * @notice Mints a license token to a user.
     * @param to The recipient of the license token.
     * @param tokenId The ERC-1155 token identifier.
     * @param amount The amount to mint.
     */
    function mint(address to, uint256 tokenId, uint256 amount) external onlyRegistry {
        _mint(to, tokenId, amount, "");
    }

    /**
     * @notice Burns a license token from a user.
     * @param from The token holder whose balance should be reduced.
     * @param tokenId The ERC-1155 token identifier.
     * @param amount The amount to burn.
     */
    function burn(address from, uint256 tokenId, uint256 amount) external onlyRegistry {
        _burn(from, tokenId, amount);
    }

    /**
     * @notice Returns the EIP-2981 royalty quote for a token sale.
     * @dev Marketplaces call this on the token, while the royalty basis points and receiver are resolved from the registry.
     * @param tokenId The ERC-1155 token identifier.
     * @param salePrice The sale price used for the royalty quote.
     * @return receiver The royalty receiver.
     * @return royaltyAmount The royalty amount owed.
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount) {
        return ILicenseRegistry(registry).royaltyInfo(tokenId, salePrice);
    }

    /**
     * @notice ERC-165 interface support declaration.
     * @param interfaceId The queried interface identifier.
     * @return supported True when the interface is supported.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Upgradeable, IERC165) returns (bool supported) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @notice Internal transfer hook used to enforce registry-defined transfer rules.
     * @dev Transfers are only allowed for transferable license types, and the registry is notified to move expiration state.
     * @param from The previous holder.
     * @param to The new holder.
     * @param ids The transferred token identifiers.
     * @param values The transferred amounts.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        if (from != address(0) && to != address(0)) {
            ILicenseRegistry registry_ = ILicenseRegistry(registry);
            uint256 idsLength = ids.length;

            for (uint256 i = 0; i < idsLength; ++i) {
                uint256 tokenId = ids[i];

                if (!registry_.isLicenseTransferable(tokenId)) {
                    revert TransferNotAllowed(tokenId);
                }
                if (balanceOf(to, tokenId) != 0) {
                    revert DuplicateLicenseHolder(to, tokenId);
                }
            }

            super._update(from, to, ids, values);

            for (uint256 i = 0; i < idsLength; ++i) {
                registry_.syncLicenseTransfer(from, to, ids[i], values[i]);
            }

            return;
        }

        super._update(from, to, ids, values);
    }
}
