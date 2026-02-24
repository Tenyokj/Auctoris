# FlashAlliance Operations

**Daily Operations**
1. Monitor new alliances created via `AllianceFactory`.
2. Track alliance state transitions (`Funding` -> `Acquired` -> `Closed`).
3. Verify critical events: `NFTBought`, `SaleExecuted`, `FundingCancelled`, `EmergencyWithdrawn`.

**Runbook: New Alliance**
1. Ensure participants and shares are correct (sum must be 100).
2. Create alliance through factory.
3. Record alliance address and owner/admin address.

**Runbook: Funding Failure**
1. Wait until funding deadline passes.
2. Participant calls `cancelFunding`.
3. Each participant calls `withdrawRefund`.

**Runbook: Sale Execution**
1. Seller approves NFT to alliance.
2. Participant buys NFT through `buyNFT`.
3. Participants vote via `voteToSell`.
4. Buyer approves ERC20 to alliance.
5. Participant executes sale via `executeSale`.

**Runbook: Emergency Rescue**
1. Participants vote recipient using `voteEmergencyWithdraw`.
2. Once quorum is reached, call `emergencyWithdrawNFT`.

**Observability**
1. Index alliance addresses from `AllianceCreated`.
2. Index voting and emergency events to show current proposal status.
3. Alert on stalled alliances close to deadline without target reached.
