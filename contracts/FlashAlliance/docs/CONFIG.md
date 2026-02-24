# FlashAlliance Config

**Runtime Parameters (`Alliance`)**
1. `targetPrice`: funding target in ERC20 units.
2. `deadline`: funding window in seconds from deployment.
3. `participants`: fixed participant addresses.
4. `shares`: fixed share percentages, sum must be 100.
5. `token`: ERC20 used for funding and settlement.
6. `admin`: owner for pause controls.

**Quorum Parameters**
1. `quorumPercent` default: `60`.
2. `lossSaleQuorumPercent` default: `80`.
3. `minSalePrice` initialized to `targetPrice`.

**Deploy Script Environment**
Required:
1. `TOKEN_OWNER`

Optional:
1. `CREATE_SAMPLE_ALLIANCE`
2. `SAMPLE_TOKEN`
3. `SAMPLE_TARGET_PRICE_WEI`
4. `SAMPLE_DEADLINE_SECONDS`
5. `SAMPLE_PARTICIPANTS`
6. `SAMPLE_SHARES`

See exact usage in `../scripts/docs_deploy/DEPLOY.md`.
