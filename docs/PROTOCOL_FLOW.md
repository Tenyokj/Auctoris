# Auctoris Protocol Flow

## Creator flow

### 1. Register an asset

The creator calls:

```solidity
createAsset(metadataURI)
```

This creates a new `assetId`.

The asset represents the licensable object, such as:

1. A music track
2. A source-code package
3. A dataset
4. A digital collectible media file
5. A commercial content bundle

### 2. Define a license type

The creator calls:

```solidity
createLicenseType(assetId, price, paymentToken, duration, transferable, royaltyBps)
```

This creates:

1. A new `licenseTypeId`
2. A deterministic ERC-1155 `tokenId`
3. Commercial terms for future buyers

Each license type can represent a different commercial package, for example:

1. Personal use
2. Commercial use
3. Team seat
4. Enterprise seat
5. Time-limited subscription

### 3. Configure the sale

The creator may then:

1. Pause or resume the asset
2. Pause or resume a specific license type
3. Update metadata
4. Update pricing and payment token
5. Update transferability
6. Update royalty basis points

## Buyer flow

### Direct purchase

A buyer can purchase directly through:

```solidity
buyLicense(assetId, licenseTypeId)
```

or batch purchase through:

```solidity
buyLicenses(items)
```

If the purchase succeeds:

1. Payment is settled
2. The ERC-1155 token is minted if needed
3. Expiration is created or extended
4. The purchase event is emitted

### Off-chain signed order flow

The creator can also authorize a sale off-chain with an EIP-712 signature.

Then a buyer fills it on-chain through:

```solidity
buyLicenseWithOrder(order, signature)
```

This is useful when:

1. The creator wants special pricing
2. The creator wants to target a specific buyer
3. The creator wants to distribute order payloads through a backend
4. The creator wants campaign-style sales or private deals

## Validation flow

The most important integration path is:

```solidity
hasValidLicense(user, assetId, licenseTypeId)
```

This returns `true` only when all required conditions hold.

Conceptually, the registry checks:

1. The asset exists and is active
2. The license type exists and is active
3. The token contract is linked
4. The user holds the correct ERC-1155 token
5. The stored expiration is perpetual or still in the future

Integrations that need more detail should call:

```solidity
getLicenseState(user, assetId, licenseTypeId)
```

That returns:

1. `tokenId`
2. `balance`
3. `expiration`
4. `valid`

## Transfer flow

If a license type is marked non-transferable:

1. The token cannot be moved between wallets
2. The transfer reverts on the token contract

If a license type is transferable:

1. The ERC-1155 balance can be moved
2. The registry updates expiration ownership from sender to receiver
3. Duplicate-holder protection prevents one wallet from accumulating the same license token twice

## Revoke flow

The asset controller or protocol owner can revoke an issued license.

Revocation does:

1. Burn the holder balance for that token id
2. Clear stored expiration
3. Emit a revoke event

This is useful when:

1. A commercial agreement is terminated
2. A mistaken grant needs to be undone
3. Abuse or fraud is detected
4. A support or compliance team needs administrative control
