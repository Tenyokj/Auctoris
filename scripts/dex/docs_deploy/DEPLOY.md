# Deploy AlsoSwap Protocol

## TL;DR
```bash
# 1) Start a local node
npx hardhat node

# 2) Deploy full DEX stack (transparent proxies)
npm run deploy:dex:local

# 3) Upgrade one proxy (example)
PROXY_ADMIN=0x<proxy_admin> \
PROXY=0x<proxy> \
IMPL=RouterV2 \
npm run upgrade:dex:local
```

## Requirements
1. `node >= 22.10`
2. Install dependencies: `npm i`
3. Optional: create `.env` for sepolia deployment and script params

## General Information
Deployment uses OpenZeppelin v5 `TransparentUpgradeableProxy`.

Each proxy deployment creates its own `ProxyAdmin` contract, and `PROXY_ADMIN_OWNER` (or deployer by default) becomes the owner.

`deploy-proxies.ts` does the following:
1. Deploys core DEX modules behind proxies
2. Deploys `MockWETH` if `WETH_ADDRESS` is not provided
3. Configures `PoolFactory` fee settings and flash limiter
4. Optionally transfers `PoolFactory` ownership to governance
5. Prints proxy addresses, implementation addresses, and per-proxy `ProxyAdmin` addresses

## Deployment Config
Optional env vars:
1. `PROXY_ADMIN_OWNER` default: deployer
2. `WETH_ADDRESS` default: deploy `MockWETH`
3. `SWAP_FEE_BPS` default: `30`
4. `PROTOCOL_FEE_BPS` default: `5`
5. `FLASH_DEFAULT_MAX_OUT_BPS` default: `3000`
6. `GOV_MIN_DELAY` default: `3600`
7. `TRANSFER_FACTORY_TO_GOVERNANCE` default: `false`

Network vars:
1. `LOCAL_RPC_URL` default: `http://127.0.0.1:8545`
2. `SEPOLIA_RPC_URL`
3. `DEPLOYER_KEY`

## Localhost Deployment
1. Start node:
```bash
npx hardhat node
```
2. Deploy:
```bash
npm run deploy:dex:local
```
3. Save output values:
1. Proxy addresses (`DEX_FACTORY`, `DEX_ROUTER`, ...)
2. Per-proxy `ProxyAdmin` addresses
3. Implementation addresses

Notes:
1. Restarting `hardhat node` resets all local addresses/state.
2. Run via `hardhat run`, not plain `tsx`.

## Sepolia Deployment
This repository is intended for testnet, not mainnet.

1. Fill `.env`:
```bash
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/<id>
DEPLOYER_KEY=0x<private_key>
PROXY_ADMIN_OWNER=0x<owner_optional>
```
2. Deploy:
```bash
npm run deploy:dex:sepolia
```

## Verify Deployment
`verify-deploy.ts` checks wiring and config for deployed proxies.

Run:
```bash
DEX_WETH=0x... \
DEX_FACTORY=0x... \
DEX_ROUTER=0x... \
DEX_ROUTER_V2=0x... \
DEX_ORACLE=0x... \
DEX_FEE_COLLECTOR=0x... \
DEX_FLASH_LIMITER=0x... \
DEX_GOVERNANCE=0x... \
npm run verify:dex:local
```

For sepolia use `npm run verify:dex:sepolia`.

## Upgrade A Proxy
`upgrade-proxy.ts` deploys a new implementation and upgrades one proxy through `ProxyAdmin`.

Important:
1. `PROXY` is the proxy address from deployment summary
2. `PROXY_ADMIN` is the corresponding `ProxyAdmin` address
3. `IMPL` is Solidity contract name, not file name

Example:
```bash
PROXY_ADMIN=0x<proxy_admin> \
PROXY=0x<proxy> \
IMPL=RouterV2 \
GAS_LIMIT=5000000 \
npm run upgrade:dex:local
```

With `upgradeAndCall`:
```bash
PROXY_ADMIN=0x<proxy_admin> \
PROXY=0x<proxy> \
IMPL=RouterV2 \
CALL=initializeV2 \
ARGS='[123]' \
GAS_LIMIT=5000000 \
npm run upgrade:dex:local
```

If `PROXY_ADMIN` is omitted, script reads admin from EIP-1967 slot.

## Troubleshooting
1. `HHE504/HHE506` for `--proxy...` flags: use env vars, not custom CLI flags.
2. `Failed to make POST request to 127.0.0.1:8545`: start local node first.
3. `Deployer is not ProxyAdmin owner`: switch signer or transfer ProxyAdmin ownership.
4. `implementation not found`: ensure new contract compiles and name matches `IMPL`.

## Post-Deploy Checks
1. Check proxy code:
```bash
npx hardhat console --network localhost
```
```js
const connection = await hre.network.connect();
const { ethers } = connection;
await ethers.provider.getCode("<proxy_address>");
```
2. Check admin and implementation slots:
```js
const adminSlot = ethers.toBeHex(BigInt(ethers.keccak256(ethers.toUtf8Bytes("eip1967.proxy.admin"))) - 1n, 32);
const implSlot = ethers.toBeHex(BigInt(ethers.keccak256(ethers.toUtf8Bytes("eip1967.proxy.implementation"))) - 1n, 32);
const admin = await ethers.provider.getStorage("<proxy_address>", adminSlot);
const impl = await ethers.provider.getStorage("<proxy_address>", implSlot);
ethers.getAddress(ethers.dataSlice(admin, 12));
ethers.getAddress(ethers.dataSlice(impl, 12));
```
3. Run one-command verifier:
```bash
npm run verify:dex:local
```
