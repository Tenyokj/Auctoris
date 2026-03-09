**Upgrade Guide**

**Contents**
1. Preconditions
2. Upgrade Command
3. Upgrade With Call
4. Post-Upgrade Checks
5. Common Pitfalls

**Preconditions**
1. New implementation keeps compatible storage layout
2. Correct `PROXY` and `PROXY_ADMIN` are known
3. Signer is owner of target `ProxyAdmin`

**Upgrade Command**
```bash
PROXY_ADMIN=0x... \
PROXY=0x... \
IMPL=RouterV3 \
npm run upgrade:dex:local
```

**Upgrade With Call**
```bash
PROXY_ADMIN=0x... \
PROXY=0x... \
IMPL=RouterV3 \
CALL='initializeV3(uint256)' \
ARGS='[123]' \
npm run upgrade:dex:local
```

**Post-Upgrade Checks**
1. Confirm implementation slot changed to new implementation
2. Confirm critical read methods still return expected values
3. Run `npm run verify:dex:local`
4. Run smoke swaps/add/remove liquidity

**Common Pitfalls**
1. Passing `--proxy` flags to hardhat run instead of env vars
2. Using implementation file name instead of contract name
3. Using wrong local session addresses after node restart
4. Using non-owner signer for ProxyAdmin upgrade tx
