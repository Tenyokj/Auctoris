**Deploy FlashAlliance (Hardhat)**

**TL;DR**
```bash
# 1) Start local node
npx hardhat node

# 2) Deploy token + factory
TOKEN_OWNER=0xYourTokenOwner \
npx hardhat run scripts/deploy/deploy-alliance.ts --network localhost

# 3) (Optional) Deploy one sample alliance in same run
TOKEN_OWNER=0xYourTokenOwner \
CREATE_SAMPLE_ALLIANCE=true \
SAMPLE_TARGET_PRICE_WEI=1000000000000000000000 \
SAMPLE_DEADLINE_SECONDS=604800 \
SAMPLE_PARTICIPANTS=0x111...,0x222... \
SAMPLE_SHARES=60,40 \
npx hardhat run scripts/deploy/deploy-alliance.ts --network localhost
```

**Requirements**
1. `node >= 22.10`
2. Install deps: `npm i`
3. Prepare network config in `hardhat.config.ts`
4. Set required env vars

**General Information**
FlashAlliance deployment is non-upgradeable and straightforward:
1. Deploy `FATK`
2. Deploy `AllianceFactory`
3. (Optional) Create one sample `Alliance`

No proxies, no ProxyAdmin, no role wiring from BERT core are required.
Admin model is local `Ownable`:
- `AllianceFactory.createAlliance(...)` caller becomes `owner` of created `Alliance`
- `Alliance.owner()` controls pause/unpause

**Deployment Config**
Required env vars:
1. `TOKEN_OWNER` - owner of `FATK` (mint/pause rights)

Optional env vars:
1. `CREATE_SAMPLE_ALLIANCE` (`true` to auto-create one alliance)
2. `SAMPLE_TOKEN` (defaults to freshly deployed `FATK`)
3. `SAMPLE_TARGET_PRICE_WEI`
4. `SAMPLE_DEADLINE_SECONDS`
5. `SAMPLE_PARTICIPANTS` (comma-separated addresses)
6. `SAMPLE_SHARES` (comma-separated ints, must sum to 100)

Network/private key setup is handled by your Hardhat config and environment (for example `SEPOLIA_RPC_URL`, `DEPLOYER_KEY`).

**Localhost Deployment**
1. Start node:
```bash
npx hardhat node
```

2. Deploy:
```bash
TOKEN_OWNER=0xYourTokenOwner \
npx hardhat run scripts/deploy/deploy-alliance.ts --network localhost
```

3. Save output addresses:
1. `FATK deployed: <address>`
2. `AllianceFactory deployed: <address>`

Notes:
1. If `hardhat node` restarts, all deployed addresses reset.
2. Use `npx hardhat run` (not direct `tsx`) to ensure Hardhat runtime context.

**Sepolia Deployment**
1. Add Sepolia network entry to `hardhat.config.ts`.
2. Configure env vars used by your Hardhat network setup.
3. Run deploy script:
```bash
TOKEN_OWNER=0xYourTokenOwner \
npx hardhat run scripts/deploy/deploy-alliance.ts --network sepolia
```

Optional sample alliance on Sepolia:
```bash
TOKEN_OWNER=0xYourTokenOwner \
CREATE_SAMPLE_ALLIANCE=true \
SAMPLE_TARGET_PRICE_WEI=1000000000000000000000 \
SAMPLE_DEADLINE_SECONDS=604800 \
SAMPLE_PARTICIPANTS=0x111...,0x222... \
SAMPLE_SHARES=60,40 \
npx hardhat run scripts/deploy/deploy-alliance.ts --network sepolia
```

**Create Alliance Manually (after deploy)**
```bash
npx hardhat console --network localhost
```
```js
const factory = await ethers.getContractAt("AllianceFactory", "<factory_address>");
const tx = await factory.createAlliance(
  ethers.parseEther("1000"),
  7 * 24 * 60 * 60,
  ["<participant1>", "<participant2>"],
  [60, 40],
  "<token_address>"
);
await tx.wait();
```

**Troubleshooting**
1. `Missing env var: TOKEN_OWNER` means `TOKEN_OWNER` was not provided.
2. `SAMPLE_PARTICIPANTS and SAMPLE_SHARES length mismatch` means comma-separated lists have different lengths.
3. Factory revert `shares must sum to 100` means sample shares are invalid.
4. If deployed addresses suddenly stop working on localhost, node was likely restarted.

**Post-Deploy Checks**
Run quick checks in Hardhat console:

1. Confirm contract code exists:
```js
await ethers.provider.getCode("<token_address>");
await ethers.provider.getCode("<factory_address>");
```
Expected: not `"0x"`.

2. Confirm token owner:
```js
const token = await ethers.getContractAt("FATK", "<token_address>");
await token.owner();
```
Expected: `TOKEN_OWNER`.

3. Confirm factory can return registry list:
```js
const factory = await ethers.getContractAt("AllianceFactory", "<factory_address>");
await factory.getAllAlliances();
```

4. After creating one alliance, verify owner and config:
```js
const a = await factory.alliances(0);
const alliance = await ethers.getContractAt("Alliance", a);
await alliance.owner();
await alliance.targetPrice();
await alliance.getParticipants();
```

5. Smoke path on test network:
1. Mint token to participants
2. `approve + deposit`
3. `buyNFT`
4. `voteToSell`
5. `executeSale`
