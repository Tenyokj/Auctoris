# FlashAlliance Config

**Runtime Parameters (`Alliance`)**
1. `targetPrice`: funding target in ERC20 units.
2. `deadline`: funding window in seconds from deployment.
3. `participants`: fixed participant addresses.
4. `shares`: fixed share percentages, sum must be 100.
5. `token`: ERC20 used for funding and settlement.
6. `admin`: owner for pause controls.
7. `quorumPercent`: base quorum for acquisition, emergency withdrawal, and standard sale.
8. `lossSaleQuorumPercent`: higher quorum for below-threshold sale execution.
9. `minSalePrice`: threshold that separates standard and loss sale quorums.

**Funding Quotas**
1. Each participant gets a fixed `requiredContribution` derived from `targetPrice` and their share.
2. Deposits cannot exceed the participant's own quota.
3. The last participant receives any rounding remainder so all quotas sum exactly to `targetPrice`.

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
7. `SAMPLE_QUORUM_PERCENT`
8. `SAMPLE_LOSS_SALE_QUORUM_PERCENT`
9. `SAMPLE_MIN_SALE_PRICE_WEI`

See exact usage in `../scripts/docs_deploy/DEPLOY.md`.
