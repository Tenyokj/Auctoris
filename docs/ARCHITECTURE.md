# Auctoris Architecture

## Overview

**Auctoris Licensing Authority** is an upgradeable on-chain licensing protocol where licenses are represented as ERC-1155 access keys and commercial policy is enforced by a registry.

The protocol is intentionally compact:

```text
[ LicenseRegistryUpgradeable ]  <- source of truth for assets, terms, purchases, validity
        |
        v
[ LicenseTokenUpgradeable ]     <- ERC-1155 balances and transfer enforcement

[ LicenseChecker ]              <- read-only helper for third-party integrations
```

## Core contract responsibilities

### `LicenseRegistryUpgradeable`

The registry is the main protocol contract.

It is responsible for:

1. Creating assets
2. Creating and updating license types
3. Mapping `(assetId, licenseTypeId)` to `tokenId`
4. Selling licenses for ETH or ERC20
5. Executing creator-signed EIP-712 orders
6. Tracking expiration timestamps
7. Revoking licenses
8. Serving metadata and royalty quotes
9. Acting as the policy engine for token transfers

In practice, this is the contract that defines whether a license is valid.

### `LicenseTokenUpgradeable`

This is the ERC-1155 balance layer.

It is intentionally thin and does not own the business rules.

It is responsible for:

1. Minting and burning balances when instructed by the registry
2. Returning metadata through the registry
3. Returning EIP-2981 royalty quotes through the registry
4. Blocking transfers when the registry marks a license type as non-transferable
5. Syncing expiration ownership on transfer

This means the token contract is not the source of truth for commercial rules.

### `LicenseChecker`

This is a small read-only helper contract.

It forwards a limited subset of read methods:

1. `getTokenId`
2. `hasValidLicense`
3. `getExpiration`
4. `getLicenseState`

It exists for integrations that want a narrow verification surface.

## Storage model

At a high level, the registry stores:

1. Assets
2. License terms
3. Token identifiers
4. User expirations
5. Signed-order replay protection

The important mapping relationship is:

```text
(assetId, licenseTypeId) -> tokenId
(user, tokenId) -> expiration
```

License validity is therefore computed from:

1. Asset exists and is active
2. License type exists and is active
3. User holds the ERC-1155 token
4. Expiration is zero or in the future

## Upgrade model

Auctoris uses the **transparent proxy pattern**.

Why:

1. Upgrade logic is kept out of the implementation runtime bytecode
2. `ProxyAdmin` isolates upgrade authority
3. Production operations are easier to reason about than with inline UUPS logic
4. The main registry stays below the EVM contract size limit more comfortably

## Trust boundaries

### What the chain guarantees

The protocol itself guarantees:

1. Deterministic token ids
2. On-chain payment settlement
3. On-chain expiration logic
4. On-chain transfer restrictions
5. On-chain revoke logic
6. On-chain signed-order verification

### What remains off-chain

The protocol does not decide:

1. The legal wording of the license document
2. The meaning of asset metadata
3. How a platform chooses to consume access checks
4. Whether an external platform caches results or checks in real time

## Recommended integration posture

For serious partners, offer three layers:

1. Direct contract integration for web3-native platforms
2. A TypeScript SDK for easier client and backend adoption
3. A hosted REST API for web2 platforms that do not want to speak ABI/RPC directly
