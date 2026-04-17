# Auctoris API

## Short answer

Yes, what you heard about an "API" can partially refer to methods like `hasValidLicense`, but that is only one layer.

`hasValidLicense` is an **on-chain read method**, not a full external platform API by itself.

In practice, Auctoris can expose three different integration surfaces:

1. **Contract API**
   The smart contract ABI and public/view functions
2. **SDK**
   A TypeScript package wrapping contract calls and common workflows
3. **Hosted integration API**
   A REST or GraphQL service run by the organization for platforms that do not want to talk to Ethereum directly

## 1. Contract API

This is the most direct form of integration.

A platform talks to Ethereum RPC and calls the contracts.

The most important read methods are:

1. `hasValidLicense(user, assetId, licenseTypeId)`
2. `getLicenseState(user, assetId, licenseTypeId)`
3. `getTokenId(assetId, licenseTypeId)`
4. `getExpiration(user, tokenId)`
5. `getAsset(assetId)`
6. `getLicenseTerms(assetId, licenseTypeId)`

This is the best path for:

1. Wallet-native dapps
2. Marketplaces
3. On-chain integrations
4. Crypto-native partners

### Why `hasValidLicense` matters

`hasValidLicense` is the cleanest access-check method.

A partner platform can do:

```ts
const valid = await registry.hasValidLicense(user, assetId, licenseTypeId);
```

If `valid === true`, the user currently has the right license.

So yes, this function is part of your public protocol interface.

But it is still not the whole "API" in the product sense.

## 2. SDK

If you want partners to integrate quickly, the next step after ABI is an SDK.

Example package direction:

```text
@auctoris/sdk
```

The SDK should wrap:

1. Contract addresses per network
2. ABI loading
3. Read helpers
4. Purchase helpers
5. Event parsing
6. Signed-order helpers

### Example SDK shape

```ts
import { AuctorisClient } from "@auctoris/sdk";

const client = new AuctorisClient({
  chainId: 11155111,
  rpcUrl: process.env.SEPOLIA_RPC_URL!,
  registryAddress: "0x...",
});

const state = await client.getLicenseState({
  user: "0xUser",
  assetId: 1n,
  licenseTypeId: 0n,
});
```

The SDK is usually the best "developer experience" layer.

## 3. Hosted integration API

This is what most web2 platforms think of as an API.

Instead of calling Ethereum contracts directly, they call your backend.

Your backend then:

1. Reads from chain
2. Optionally indexes data into a database
3. Returns normalized JSON responses

This is useful for:

1. SaaS platforms
2. CMS systems
3. Music platforms
4. Content paywalls
5. Enterprise partners
6. Teams without blockchain engineers

## Recommended REST API shape

### Validation endpoints

```text
GET /v1/licenses/check?user=0x...&assetId=1&licenseTypeId=0
GET /v1/licenses/state?user=0x...&assetId=1&licenseTypeId=0
GET /v1/users/:address/licenses
```

### Catalog endpoints

```text
GET /v1/assets/:assetId
GET /v1/assets/:assetId/licenses
GET /v1/assets/:assetId/licenses/:licenseTypeId
```

### Purchase-support endpoints

```text
GET /v1/networks
GET /v1/contracts
POST /v1/orders/prepare
POST /v1/orders/quote
```

### Example response for a validation endpoint

```json
{
  "protocol": "Auctoris Licensing Authority",
  "network": "sepolia",
  "registry": "0xRegistry",
  "user": "0xUser",
  "assetId": "1",
  "licenseTypeId": "0",
  "tokenId": "340282366920938463463374607431768211456",
  "balance": "1",
  "expiration": "0",
  "valid": true
}
```

## How to build the hosted API correctly

### Minimal version

The simplest version is a backend that does live reads against Ethereum RPC.

Flow:

1. Partner calls your REST endpoint
2. Backend calls `getLicenseState` on the registry
3. Backend returns JSON

This is easy to build, but not ideal at scale.

### Production version

The stronger architecture is:

1. **Indexer worker**
   Subscribes to events and stores normalized data
2. **Read API service**
   Serves fast JSON from a database
3. **Chain verifier layer**
   Uses direct contract reads for final truth when needed

### Recommended backend stack

One good practical stack:

1. Node.js + TypeScript
2. `viem` or `ethers`
3. PostgreSQL
4. Redis for caching if needed
5. Queue worker for indexing and retries

### Events to index

At minimum, index:

1. `AssetCreated`
2. `AssetMetadataURIUpdated`
3. `AssetActiveSet`
4. `AssetCreatorTransferred`
5. `LicenseTypeCreated`
6. `LicenseTermsUpdated`
7. `LicenseTypeActiveSet`
8. `LicenseMetadataURIUpdated`
9. `LicensePurchased`
10. `LicenseRevoked`
11. `SignedOrderUsed`

## Best integration model for partners

If you want platforms to integrate your protocol seriously, the strongest offering is:

1. **On-chain contracts**
   The source of truth
2. **REST API**
   Easy integration path for platforms
3. **SDK**
   Better developer experience
4. **Documentation**
   Exact flows and examples

That combination makes the protocol feel institutional.

## Suggested first roadmap

If you want to implement this cleanly, the order should be:

1. Keep the contracts as the source of truth
2. Publish stable Sepolia addresses
3. Build a small TypeScript SDK
4. Build a REST read API
5. Add indexed catalog endpoints
6. Add signed-order preparation endpoints if you want server-assisted commerce

## Answer in one sentence

`hasValidLicense` is the core **protocol read method**, while the real "Auctoris API" for external platforms would be a separate backend and SDK layer built on top of these contract reads.
