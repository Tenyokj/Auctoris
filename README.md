![Flash-Alliances v1.0.0](https://img.shields.io/static/v1?label=Flash-Alliances&message=%20v1.0.0&color=6B8E23) ![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-green)
![Node.js >=22](https://img.shields.io/badge/Node.js->=22-brightgreen) ![TypeScript 5.8.0](https://img.shields.io/badge/TypeScript-5.8.0-3178C6) ![Hardhat 3.0.15](https://img.shields.io/badge/Hardhat-3.0.1-yellow) ![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-orange) ![Ethers 6.15.0](https://img.shields.io/badge/Ethers-6.15.0-3C3C3D) ![Tests: Unit passing](https://img.shields.io/badge/Tests%3A%20Unit-passing-success) ![Tests: Coverage >95%](https://img.shields.io/badge/coverage-95%25-orange)
![Tests: Integration: Scratch passing](https://img.shields.io/badge/Tests%3A%20Integration%3A%20Scratch-passing-success) ![Tests: Integration: Sepolia Fork passing](https://img.shields.io/badge/Tests%3A%20Integration%3A%20Sepolia%20Fork-passing-success) ![Linters passing](https://img.shields.io/badge/Linters-passing-success)

![FlashAlliance Banner](./docs/flash-asset.png)

**FlashAlliance**
is a standalone ERC20-funded collective NFT trading module.
Each `Alliance` instance is a self-contained pool with fixed participants and fixed ownership shares.

**FlashAlliance** is designed as a lightweight, capital-efficient coordination layer for small groups that want to acquire and manage high-value NFTs together.

There is no global DAO dependency.
Each Alliance operates independently.

Note: Please read the Contract [Documentation](https://flash-docs.vercel.app) before integrating with this repo.

**Core Flow**

1. Participants deposit ERC20 in `Funding`.
2. Each participant deposits only up to their fixed funding quota.
3. Alliance buys NFT when target is reached.
4. Participants vote sale params in `Acquired`.
5. Sale executes and proceeds become claimable by fixed shares.
6. If funding fails, participants withdraw refunds.
7. Emergency NFT withdrawal is available via participant quorum and expiry-based reset.


**Contract Documentation**
See: [docs/CONTRACTS.md](docs/CONTRACTS.md)

**Learn More**
1. Flash Alliances site: [website](https://flash-alliances.vercel.app)
2. Flash Alliances front: [repository](https://github.com/Tenyokj/FlashAlliance-front.git)

**Docs**

1. Architecture: [ARCHITECTURE.md](docs/ARCHITECTURE.md)
2. Security: [SECURITY.md](docs/SECURITY.md)
3. Upgrades: [UPGRADES.md](docs/UPGRADES.md)
4. Configuration: [CONFIG.md](docs/CONFIG.md)
5. Operations: [OPERATIONS.md](docs/OPERATIONS.md)
6. FAQ: [FAQ.md](docs/FAQ.md)
7. Glossary: [GLOSSARY.md](docs/GLOSSARY.md)
8. Getting Started: [GETTING_STARTED.md](docs/GETTING_STARTED.md)

**Disclaimer**

This repository contains the core smart contracts of the protocol. The codebase may evolve rapidly, so older guides may not match the current layout. Refer to the latest docs for accurate integration guidance.

**License**

2025 BERT info@tenyokj

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3 of the License, or any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see https://www.gnu.org/licenses/.
