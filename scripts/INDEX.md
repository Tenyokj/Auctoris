# Deployment Scripts Index

## Scripts
1. `scripts/dex/deploy-proxies.ts` deploy full DEX protocol with transparent proxies
2. `scripts/dex/upgrade-proxy.ts` upgrade a single proxy
3. `scripts/dex/verify-deploy.ts` post-deploy checks (wiring, pause status, config)

## Docs
1. `/dex/docs_deploy/DEPLOY.md` deployment and upgrade guide

## Notes
1. Use `hardhat run` scripts, not plain `tsx`
2. For localhost deployment, keep `npx hardhat node` running
3. For sepolia, configure `SEPOLIA_RPC_URL` and `DEPLOYER_KEY` in `.env`
