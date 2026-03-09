![AlsoSwap v1.0.0](https://img.shields.io/badge/AlsoSwap-v1.0.0-0EA5E9) ![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-green)
![Node.js >=22](https://img.shields.io/badge/Node.js->=22-brightgreen) ![TypeScript 5.8.0](https://img.shields.io/badge/TypeScript-5.8.0-3178C6) ![Hardhat 3.0.15](https://img.shields.io/badge/Hardhat-3.0.15-yellow)
![Solidity ^0.8.20](https://img.shields.io/badge/Solidity-^0.8.20-orange) ![Upgradeable: Transparent Proxy](https://img.shields.io/badge/Upgradeable-Transparent%20Proxy-blueviolet) ![DEX](https://img.shields.io/badge/DeFi-AMM%20DEX-purple)
![Ethers 6.15.0](https://img.shields.io/badge/Ethers-6.15.0-3C3C3D) ![Tests: Unit passing](https://img.shields.io/badge/Tests%3A%20Unit-passing-success) ![Coverage >95%](https://img.shields.io/badge/Coverage-%3E95%25-success)

![AlsoSwap Banner](./docs/assets/alsoswap.png)

# AlsoSwap Protocol

**AlsoSwap Protocol** is an upgradeable AMM DEX for DAO and community ERC20 tokens in Ethereum Sepolia.

It provides a full on-chain stack for token listing, liquidity provisioning, and token exchange with constant-product pricing. Projects can launch pools for governance tokens, LPs can provide liquidity and earn fees, and users can swap tokens through a router with slippage/deadline controls.

This repository contains the core protocol contracts, deployment scripts, upgrade scripts, verification scripts, and high-coverage test suites.

## Table of Contents
1. [Why AlsoSwap](#why-alsoswap)
2. [What You Can Do](#what-you-can-do)
3. [Protocol Components](#protocol-components)
4. [How It Works](#how-it-works)
5. [Security and Upgrade Model](#security-and-upgrade-model)
6. [Quick Start](#quick-start)
7. [Deployment and Upgrade](#deployment-and-upgrade)
8. [Documentation Map](#documentation-map)
9. [Roadmap](#roadmap)
10. [Disclaimer](#disclaimer)
11. [License](#license)

## Why AlsoSwap
1. Built for DAO token ecosystems: easy onboarding of project tokens into AMM pools.
2. Real liquidity and market-driven pricing: pool reserves define executable spot price.
3. Practical developer stack: routers, oracle, governance, and proxy-based upgrades.
4. Testnet-first safety: strong engineering practices without mainnet-level economic assumptions.

## What You Can Do
1. Create pools for any ERC20 pair through `PoolFactory`.
2. Add and remove liquidity with LP share accounting.
3. Swap tokens via `Router` and optimized `RouterV2` paths.
4. Swap ETH paths through WETH wrappers.
5. Use flash swap mechanics for advanced integrations.
6. Query TWAP from `PriceOracle` for safer external pricing usage.
7. Control protocol parameters with timelocked governance flows.

## Protocol Components

### Core
1. `PoolFactory` - pool registry, global fees, fee receiver, limiter, pause root.
2. `LiquidityPool` - AMM reserves, LP token mint/burn, swap, flash swap, cumulative pricing.
3. `Router` - user-facing add/remove liquidity and swaps with slippage/deadline checks.
4. `RouterV2` - best-path selection for direct and 2-hop routes.

### Governance and Upgradeability
1. `DEXGovernance` - delayed execution for sensitive protocol changes.
2. `DEXTransparentProxyFactory` - helper for transparent proxy deployments.
3. Transparent proxies for upgradeable modules with per-proxy `ProxyAdmin` control.

### Treasury, Oracle, Extensions
1. `FeeCollector` - protocol fee accumulation and controlled withdrawals.
2. `PriceOracle` - TWAP observations and consult API.
3. `FlashLoanLimiter` - flash output policy bounds.
4. `LiquidityMining` - optional LP staking incentives.

## How It Works
1. A DAO token project creates or reuses a pool for token pairs.
2. Liquidity providers deposit both assets and receive LP shares.
3. Traders swap through router endpoints.
4. Pool output is calculated from constant-product math with fee logic.
5. Protocol fee portion is sent to treasury.
6. Oracle tracks cumulative prices for TWAP-based quoting.
7. Governance can update fee and safety parameters via timelock.

## Security and Upgrade Model
1. `SafeERC20`, custom errors, and explicit input checks.
2. `ReentrancyGuard` on critical mutative methods.
3. `PausableUpgradeable` across key modules.
4. Router and pool flows respect factory pause state.
5. Transparent proxy architecture with EIP-1967 slot verifiability.
6. Storage gaps reserved for future upgrades.

## Quick Start

### Requirements
1. `node >= 22.10`
2. `npm`

### Install
```bash
npm i
```

### Compile
```bash
npm run compile
```

### Run tests
```bash
npm test
```

### Coverage
```bash
npm run coverage
```

## Deployment and Upgrade

### Local deployment
1. Run local chain:
```bash
npx hardhat node
```
2. Deploy protocol:
```bash
npm run deploy:dex:local
```
3. Verify wiring:
```bash
npm run verify:dex:local
```

### Sepolia deployment
```bash
npm run deploy:dex:sepolia
npm run verify:dex:sepolia
```

### Proxy upgrade
Use environment variables (Hardhat v3 custom params style):

```bash
PROXY_ADMIN=0x... \
PROXY=0x... \
IMPL=RouterV3 \
npm run upgrade:dex:local
```

With post-upgrade call:

```bash
PROXY_ADMIN=0x... \
PROXY=0x... \
IMPL=RouterV3 \
CALL='initializeV3(uint256)' \
ARGS='[123]' \
npm run upgrade:dex:local
```

## Documentation Map

### Main docs
1. [Getting Started](./docs/GETTING_STARTED.md)
2. [Architecture](./docs/ARCHITECTURE.md)
3. [Config](./docs/CONFIG.md)
4. [Operations](./docs/OPERATIONS.md)
5. [Security](./docs/SECURITY.md)
6. [Upgrades](./docs/UPGRADES.md)
7. [FAQ](./docs/FAQ.md)
8. [Glossary](./docs/GLOSSARY.md)

### Contracts docs
1. [Contracts Navigation](./docs/CONTRACTS.md)

### DevOps docs
1. [Deploy Guide](./scripts/dex/docs_deploy/DEPLOY.md)
2. [Deploy Scripts Index](./scripts/dex/docs_deploy/INDEX.md)
3. [Testing Guide](./test/docs_tests/TESTING.md)

## Roadmap
1. More advanced route search (multi-hop >2 and liquidity-aware ranking).
2. Additional risk controls for flash swap and pool-level limits.
3. Better analytics surface for fee and volume dashboards.
4. Optional frontend and SDK integration package.

## Disclaimer
This codebase is designed for developer usage and public testing on Sepolia. It follows strong Solidity engineering practices, but it is not positioned as audited mainnet production infrastructure by default. Always review the latest docs and run your own risk checks before integration.

## License

2026 AlsoSwap Contributors

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3 of the License, or any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the [GNU General Public License](./LICENSE) for details.

If you did not receive a copy, see: https://www.gnu.org/licenses/
