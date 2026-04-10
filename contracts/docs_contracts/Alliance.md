# Alliance

**Summary**
Core FlashAlliance contract for participant funding, NFT acquisition, sale voting, claimable settlement, refunds, and emergency NFT rescue.

**State Machine**
1. `Funding`
2. `Acquired`
3. `Closed`

**Key Features**
1. Fixed participants and fixed shares at deployment.
2. ERC20 funding with strict per-participant quotas.
3. Direct NFT purchase from seller.
4. Share-weighted sale voting.
5. Loss-sale higher quorum.
6. Emergency withdrawal voting with expiry/reset rounds.
7. Claim-based sale proceeds.
8. Refunds on failed funding.
9. Owner pause/unpause.

**Access Control**
1. `onlyParticipant` for business actions.
2. `onlyOwner` for pause controls.

**Critical Functions**
1. `deposit(uint256)`
2. `cancelFunding()`
3. `voteToAcquire(address,uint256,address,uint256,uint256)`
4. `voteToSell(address,uint256,uint256)`
5. `executeSale()`
6. `withdrawRefund()`
7. `claimProceeds()`
8. `voteEmergencyWithdraw(address,uint256)`
9. `resetEmergencyProposal()`
10. `emergencyWithdrawNFT()`

**Events**
1. `Deposit`
2. `FundingTargetReached`
3. `FundingCancelled`
4. `Refunded`
5. `NFTBought`
6. `Voted`
7. `SaleProposalReset`
8. `SaleExecuted`
9. `EmergencyVoted`
10. `EmergencyProposalReset`
11. `EmergencyWithdrawn`
12. `ProceedsAllocated`
13. `ProceedsClaimed`
