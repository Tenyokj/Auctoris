# Tenji Deployment

## Requirements

- Node.js `>= 22.10`
- npm dependencies installed
- valid RPC endpoint for the target network
- funded deployer wallet

## Contracts Deployed

Production deployment only requires:

- `TenjiCoin`
- `TenjiAirdrop`

Optional helper:

- `AirdropClaimCaller` for testing anti-bot behavior

## Environment Variables

Required for Sepolia:

- `SEPOLIA_RPC_URL`
- `DEPLOYER_KEY`
- `LIQUIDITY_WALLET`
- `TEAM_WALLET`
- `RESERVE_WALLET`
- `AIRDROP_AMOUNT_PER_USER`
- `AIRDROP_MAX_USERS`

Optional:

- `DEPLOYER_ADDRESS`
- `AIRDROP_OWNER`
- `DEPLOY_CLAIM_CALLER`
- `ETHERSCAN_API_KEY`
- `VERIFY_ON_DEPLOY`
- `VERIFY_DELAY_MS`

See `.env.example` for the expected format.

## How Deployment Works

The deployment script performs the following sequence:

1. Connects to the selected network.
2. Predicts the future address of `TenjiAirdrop`.
3. Deploys `TenjiCoin`, minting `60,000,000,000 TENJI` to liquidity, `20,000,000,000 TENJI` to team, `20,000,000,000 TENJI` directly to the predicted airdrop address, and `67,000,000,000 TENJI` to the reserve wallet.
4. Deploys `TenjiAirdrop` at the predicted address.
5. Optionally deploys `AirdropClaimCaller`.
6. Optionally verifies contracts on Etherscan.
7. Saves deployment metadata to `deployments/<network>.json`.

This design avoids the need for a separate post-deploy funding transfer into the airdrop contract.

## Validation Rules

The deployment script checks:

- required addresses are valid
- token amounts are valid decimals
- integer parameters are positive
- `amountPerUser * maxUsers` does not exceed the `20,000,000,000 TENJI` airdrop reserve

If the planned campaign uses less than the full reserve, the script prints a warning but still deploys.

## Commands

Compile:

```bash
npm run compile
```

Run tests:

```bash
npm test
```

Deploy to local node:

```bash
npm run deploy:tenji:local
```

Deploy to Sepolia:

```bash
npm run deploy:tenji:sepolia
```

## Verification

If `ETHERSCAN_API_KEY` is set, verification can be enabled on deploy.

Related variables:

- `VERIFY_ON_DEPLOY=true`
- `VERIFY_DELAY_MS=30000`

The package scripts already use `--build-profile production` so deployment and verification use a matching build profile.

## Post-Deployment Checks

After deployment, verify:

- token address
- airdrop address
- airdrop contract balance
- liquidity wallet balance
- team wallet balance
- reserve wallet balance

Example Hardhat console flow:

```bash
npx hardhat console --network sepolia
```

```js
const { ethers } = await network.connect()

const token = await ethers.getContractAt("TenjiCoin", "0xTOKEN")
const airdrop = await ethers.getContractAt("TenjiAirdrop", "0xAIRDROP")

ethers.formatUnits(await token.balanceOf(await airdrop.getAddress()), 18)
```

Expected split:

- liquidity: `60,000,000,000 TENJI`
- team: `20,000,000,000 TENJI`
- airdrop: `20,000,000,000 TENJI`
- reserve: `67,000,000,000 TENJI`
