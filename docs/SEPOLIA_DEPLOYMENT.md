# Auctoris Sepolia Deployment

## Goal

This guide describes how to deploy **Auctoris Licensing Authority** to Ethereum Sepolia using the deployment script already included in the repository.

## Requirements

You need:

1. Node.js `>= 22`
2. Installed dependencies with `npm install`
3. A Sepolia RPC URL
4. A funded Sepolia deployer wallet
5. An optional Etherscan API key for verification

## Environment setup

Create `.env` from `.env.example`:

```bash
cp .env.example .env
```

Then set:

```bash
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/...
DEPLOYER_KEY=0x...
ETHERSCAN_API_KEY=...
```

## Compile

```bash
npm run compile
```

## Test before deployment

```bash
npm test
```

## Deploy

```bash
npm run deploy:sepolia
```

The script will:

1. Deploy the registry implementation
2. Deploy the registry transparent proxy
3. Deploy the token implementation
4. Deploy the token transparent proxy
5. Link the token to the registry
6. Save a manifest to `deployments/sepolia.json`

## After deployment

Record the following from the deployment manifest:

1. Registry implementation
2. Registry proxy
3. Registry proxy admin
4. Token implementation
5. Token proxy
6. Token proxy admin

These are the addresses you will need for:

1. Frontend integration
2. API integration
3. Verification
4. Future upgrades

## Verification

The deploy script prints verification commands after deployment.

Run them one by one.

At minimum, verify:

1. Registry implementation
2. Token implementation
3. Registry proxy wrapper
4. Token proxy wrapper

## Recommended post-deploy sanity checks

After Sepolia deployment, confirm:

1. `licenseToken()` on the registry equals the token proxy address
2. A test asset can be created
3. A test license type can be created
4. A wallet can buy a license
5. `hasValidLicense` returns `true` for that wallet
6. `getLicenseState` returns the expected token id and expiration

## Recommended next step

Once Sepolia is live, the next thing to build is not more contracts.

The next thing to build is:

1. A stable address manifest for integrators
2. A TypeScript SDK
3. A hosted read API for partner platforms
