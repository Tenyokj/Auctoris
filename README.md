# Auctoris Licensing Authority

![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-green)
![Node.js >=22](https://img.shields.io/badge/Node.js->=22-brightgreen)
![Hardhat 3](https://img.shields.io/badge/Hardhat-3-yellow)
![Solidity 0.8.28](https://img.shields.io/badge/Solidity-0.8.28-orange)
![Coverage >98%](https://img.shields.io/badge/Coverage->98%25-success)
![Architecture-Transparent Proxy](https://img.shields.io/badge/Architecture-Transparent%20Proxy-103A52)
![Token Standard-ERC1155](https://img.shields.io/badge/Token-ERC1155-1A1D21)
![Payments-ETH + ERC20](https://img.shields.io/badge/Payments-ETH%20%2B%20ERC20-0F766E)
![Orders-EIP712](https://img.shields.io/badge/Orders-EIP712-7C3AED)
![Royalties-EIP2981](https://img.shields.io/badge/Royalties-EIP2981-B89A5E)
![Upgrade Admin-ProxyAdmin](https://img.shields.io/badge/Upgrade%20Admin-ProxyAdmin-334155)
![Security-Multisig Ready](https://img.shields.io/badge/Security-Multisig%20Ready-0F172A)
![Network-Sepolia Ready](https://img.shields.io/badge/Network-Sepolia%20Ready-2563EB)
![Market-Creator Audio Assets](https://img.shields.io/badge/Market-Creator%20Audio%20Assets-8B5CF6)
![Status-v1 Core Ready](https://img.shields.io/badge/Status-v1%20Core%20Ready-success)

<p align="center">
  <img src="./docs/assets/auctoris_logo.png" alt="Auctoris logo" width="180" />
</p>

**Auctoris Licensing Authority** is an upgradeable on-chain licensing stack for issuing, selling, validating, and revoking rights as ERC-1155 access keys.

The protocol is generic at the smart-contract layer, but the **first market focus for Auctoris v1** is:

**commercial licensing for creator audio assets**

That includes:

1. Background tracks
2. Podcast intro and outro packs
3. Beat packs
4. Sample packs
5. Short-form commercial-use audio assets

The protocol is built around one clear idea:

1. A creator registers an asset.
2. The creator defines one or more license types for that asset.
3. Each license type maps to one ERC-1155 token id.
4. A buyer purchases a license and receives the corresponding token.
5. Any app, marketplace, gate, or backend can verify access on-chain with balance and expiration checks.

This repository is structured for serious deployment, not just demos:

1. Upgradeable transparent proxy architecture
2. ETH and ERC20 payment support
3. Off-chain signed order fills via EIP-712
4. Batch purchase and batch revoke flows
5. EIP-2981 royalty compatibility
6. High test coverage
7. Sepolia-ready deployment flow

## Documentation

Project docs now live in [docs/README.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/README.md>).

The most important ones are:

1. [docs/ARCHITECTURE.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/ARCHITECTURE.md>)
2. [docs/PROTOCOL_FLOW.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/PROTOCOL_FLOW.md>)
3. [docs/API.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/API.md>)
4. [docs/MARKET_POSITIONING.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/MARKET_POSITIONING.md>)
5. [docs/LICENSING_MODEL.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/LICENSING_MODEL.md>)
6. [docs/ASSET_METADATA_SPEC.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/ASSET_METADATA_SPEC.md>)
7. [docs/LICENSE_TERMS_MATRIX.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/LICENSE_TERMS_MATRIX.md>)
8. [docs/BRAND_GUIDE.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/BRAND_GUIDE.md>)
9. [docs/MULTISIG_RUNBOOK.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/MULTISIG_RUNBOOK.md>)
10. [docs/SEPOLIA_DEPLOYMENT.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/SEPOLIA_DEPLOYMENT.md>)
11. [docs/OPERATIONS.md](</Users/daniilvolkova/Desktop/hardhat3 copy/docs/OPERATIONS.md>)

## Brand

The protocol identity in this repository is **Auctoris**.

Use it like this:

1. **Auctoris Licensing Authority**: the institutional name
2. **Auctoris Protocol**: the protocol stack
3. **Auctoris Registry**: the core on-chain registry layer

The EIP-712 signing domain used for off-chain order signing is:

`Auctoris Licensing Authority`

## Architecture

```text
[ LicenseRegistryUpgradeable ]  <- source of truth
        |
        v
[ LicenseTokenUpgradeable ]     <- ERC-1155 license keys

[ LicenseChecker ]              <- read helper for integrations
```

### Core contracts

1. [contracts/core/LicenseRegistryUpgradeable.sol](/Users/daniilvolkova/Desktop/hardhat3%20copy/contracts/core/LicenseRegistryUpgradeable.sol)
   The main business-logic contract for assets, license terms, payments, expirations, revocations, and signed orders.
2. [contracts/core/LicenseTokenUpgradeable.sol](/Users/daniilvolkova/Desktop/hardhat3%20copy/contracts/core/LicenseTokenUpgradeable.sol)
   The ERC-1155 token layer that stores license balances and enforces transfer policy by consulting the registry.
3. [contracts/core/LicenseChecker.sol](/Users/daniilvolkova/Desktop/hardhat3%20copy/contracts/core/LicenseChecker.sol)
   A narrow read-only helper for third-party integrations.
4. [contracts/proxy/LicenseProtocolProxy.sol](/Users/daniilvolkova/Desktop/hardhat3%20copy/contracts/proxy/LicenseProtocolProxy.sol)
   A thin transparent proxy wrapper that auto-creates a dedicated `ProxyAdmin`.

## Protocol flow

### Creator flow

1. Call `createAsset(metadataURI)`.
2. Call `createLicenseType(assetId, price, paymentToken, duration, transferable, royaltyBps)`.
3. Optionally update terms, metadata, or active flags.
4. Sell directly on-chain or distribute signed off-chain orders.

### Buyer flow

1. Buy directly with `buyLicense`.
2. Buy in batch with `buyLicenses`.
3. Fill a creator-signed order with `buyLicenseWithOrder`.
4. Receive an ERC-1155 token representing the purchased license.

### Verification flow

Any integration can verify access by calling:

1. `hasValidLicense(user, assetId, licenseTypeId)`
2. `getLicenseState(user, assetId, licenseTypeId)`
3. `LicenseChecker` if a smaller read surface is preferred

The logic is effectively:

```solidity
balanceOf(user, tokenId) > 0 && (expiration == 0 || expiration > block.timestamp)
```

with additional checks that the asset and license type are still active.

## EIP-2981 royalty compatibility

`EIP-2981` is the marketplace royalty standard used by many NFT marketplaces.

It does not enforce royalty payments on-chain by itself. Instead, it standardizes a read function:

```solidity
royaltyInfo(tokenId, salePrice) -> (receiver, royaltyAmount)
```

In Auctoris:

1. Royalty basis points are stored per license type in the registry
2. The ERC-1155 token exposes `royaltyInfo`
3. Marketplaces and secondary-sale integrations can query the token for royalty quotes

That means your license keys are compatible with royalty-aware infrastructure without embedding royalty business logic into every transfer.

## Repository layout

```text
contracts/
  core/
  interfaces/
  mocks/
  proxy/
  utils/
scripts/
  deploy/
test/
deployments/
```

## Local development

### Install

```bash
npm install
```

### Compile

```bash
npm run compile
```

### Test

```bash
npm test
```

### Coverage

```bash
npm run coverage
```

## Sepolia deployment

### 1. Prepare environment

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Required variables:

1. `SEPOLIA_RPC_URL`
2. `DEPLOYER_KEY`

Optional but recommended:

1. `ETHERSCAN_API_KEY`

### 2. Deploy

```bash
npm run deploy:sepolia
```

The deploy script will:

1. Deploy the registry implementation
2. Deploy the registry transparent proxy
3. Deploy the token implementation
4. Deploy the token transparent proxy
5. Link the token to the registry
6. Save a deployment manifest to `deployments/sepolia.json`

### 3. Verify

The deploy script prints ready-to-run verification commands after deployment.

## Deployment manifest

Each deployment writes a JSON manifest into `deployments/<network>.json`.

The manifest includes:

1. Protocol name
2. Network and chain id
3. Deployer address
4. Implementation addresses
5. Proxy addresses
6. Proxy admin addresses
7. Linking transaction hash

This gives you a clean source of truth for operations, upgrades, and frontend integration.

## Upgrade model

This repository uses the transparent proxy pattern.

Why this is the right production choice here:

1. Upgrade authority is isolated in `ProxyAdmin`
2. Implementation bytecode stays smaller and more deployable
3. Registry and token logic remain focused on business behavior
4. Upgrade permissions are easier to reason about operationally

## Notes for production

Before mainnet or public production rollout, you should still plan for:

1. Multisig ownership of the proxy admins
2. Operational monitoring for purchase and revoke flows
3. Event indexing and frontend integration
4. A clear metadata hosting policy
5. A legal and commercial review of the license templates being sold

## Commands

```bash
npm run compile
npm test
npm run coverage
npm run deploy:protocol
npm run deploy:sepolia
```

## License

This repository is released under `GPL-3.0-only`.
