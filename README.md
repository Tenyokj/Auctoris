![License: MIT](https://img.shields.io/badge/License-MIT-059669.svg)
![CI: GitHub Actions](https://img.shields.io/badge/CI-GitHub%20Actions-111827?logo=githubactions&logoColor=2088FF)
![Solidity: 0.8.27](https://img.shields.io/badge/Solidity-0.8.27-363636?logo=solidity)
![Hardhat: 3.0.15](https://img.shields.io/badge/Hardhat-3.0.15-F7DF1E)
![Node.js >=22.10](https://img.shields.io/badge/Node.js-%3E%3D22.10-5FA04E?logo=node.js&logoColor=white)
![Standard: ERC-20](https://img.shields.io/badge/Standard-ERC--20-2563EB)
![Network: Sepolia/Testnet](https://img.shields.io/badge/Network-Sepolia-627EEA?logo=ethereum&logoColor=white)

![LOGO](./docs/tenji-turttle.png)

#                                   TenjiCoin Core

TenjiCoin is a meme token built around a simple idea: the market moves too fast for most people.

Tenji is the turtle that always arrives one candle too late. It is not a mascot for perfect execution or flawless alpha. It is a mascot for the trader who misses the clean entry, hesitates on the exit, and still shows up for the next trade.

This repository contains the on-chain core of the Tenji project:

- `TenjiCoin`, a fixed-supply ERC-20 token with burn support
- `TenjiAirdrop`, an airdrop contract with single-claim enforcement and basic anti-bot rules
- `AirdropClaimCaller`, a helper contract used to test contract-call rejection
- Hardhat deployment scripts, tests, and repo-level docs

## Why Tenji Exists

The crypto market moves fast.
Too fast for most people.

Tenji exists for those who are always one step behind, not because they are stupid, but because the market never waits.

This is not a token about winning every trade.
It is a token about being late and still showing up.

## Core Facts

- Token name: `TenjiCoin`
- Symbol: `TENJI`
- Standard: ERC-20
- Decimals: 18
- Total supply: `167,000,000,000 TENJI`
- Supply model: fixed at deployment
- Minting after deployment: not supported
- Burn support: enabled for token holders
- Taxes or transfer fees: none

## Initial Allocation

- Liquidity: `60%` or `100,200,000,000 TENJI`
- Team: `10%` or `16,700,000,000 TENJI`
- Airdrop reserve: `30%` or `50,100,000,000 TENJI`

The deployment flow predicts the future `TenjiAirdrop` address and mints the full airdrop reserve directly into that contract during token deployment.

## Repository Map

- [Litepaper](./docs/litepaper.md)
- [Tokenomics](./docs/tokenomics.md)
- [Airdrop](./docs/airdrop.md)
- [Audit Status](./docs/audit.md)
- [Security](./docs/SECURITY.md)
- [Deployment](./docs/deployment.md)
- [Contracts](./docs/CONTRACTS.md)
- [FAQ](./docs/FAQ.md)
- [Roadmap](./docs/roadmap.md)
- [Contributing](./CONTRIBUTING.md)
- [Changelog](./CHANGELOG.md)

## Quick Start

Install dependencies:

```bash
npm install
```

Run the test suite:

```bash
npm test
```

Compile contracts:

```bash
npm run compile
```

Deploy locally:

```bash
npm run deploy:tenji:local
```

Deploy to Sepolia:

```bash
npm run deploy:tenji:sepolia
```

After deployment, the script writes contract addresses and deployment metadata to `deployments/<network>.json`.

## What Is In Scope

This repository is focused on the token, the airdrop system, deployment, and testing. The public website, frontend experience, and richer product-facing docs can evolve separately.

## Status

- Core token contract implemented
- Airdrop contract implemented
- Deployment flow implemented
- Unit tests included
- GitHub Actions CI included
- Markdown docs included

## Disclaimer

Tenji is a meme-driven crypto project. This repository is not financial advice, not an audited promise of safety, and not a guarantee of future value. Anyone interacting with the contracts should review the code, understand the risks, and make independent decisions.

## License

MIT. See [LICENSE](./LICENSE).
