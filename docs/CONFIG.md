**Configuration**

**Contents**
1. Network Variables
2. Deployment Variables
3. Upgrade Variables
4. Verification Variables

**Network Variables**
1. `LOCAL_RPC_URL` default: `http://127.0.0.1:8545`
2. `SEPOLIA_RPC_URL` required for Sepolia deployment
3. `DEPLOYER_KEY` required for Sepolia deployment

**Deployment Variables**
1. `PROXY_ADMIN_OWNER` default: deployer address
2. `WETH_ADDRESS` optional, deploy mock WETH if omitted
3. `SWAP_FEE_BPS` default: `30`
4. `PROTOCOL_FEE_BPS` default: `5`
5. `FLASH_DEFAULT_MAX_OUT_BPS` default: `3000`
6. `GOV_MIN_DELAY` default: `3600`
7. `TRANSFER_FACTORY_TO_GOVERNANCE` default: `false`

**Upgrade Variables**
1. `PROXY_ADMIN` target ProxyAdmin address
2. `PROXY` target proxy address
3. `IMPL` implementation contract name
4. `CALL` optional post-upgrade call signature
5. `ARGS` optional JSON array for `CALL`
6. `GAS_LIMIT` optional tx gas limit

**Verification Variables**
1. `DEX_WETH`
2. `DEX_FACTORY`
3. `DEX_ROUTER`
4. `DEX_ROUTER_V2`
5. `DEX_ORACLE`
6. `DEX_FEE_COLLECTOR`
7. `DEX_FLASH_LIMITER`
8. `DEX_GOVERNANCE`
