# Alliance

**Summary**
Core FlashAlliance contract for participant funding, NFT acquisition, sale voting, settlement, refunds, and emergency NFT rescue.

**State Machine**
1. `Funding`
2. `Acquired`
3. `Closed`

**Key Features**
1. Fixed participants and fixed shares at deployment.
2. ERC20 funding with capped target.
3. Direct NFT purchase from seller.
4. Share-weighted sale voting.
5. Loss-sale higher quorum.
6. Emergency withdrawal voting.
7. Refunds on failed funding.
8. Owner pause/unpause.

**Access Control**
1. `onlyParticipant` for business actions.
2. `onlyOwner` for pause controls.

**Critical Functions**
1. `deposit(uint256)`
2. `cancelFunding()`
3. `buyNFT(address,uint256,address)`
4. `voteToSell(address,uint256,uint256)`
5. `executeSale()`
6. `withdrawRefund()`
7. `voteEmergencyWithdraw(address)`
8. `emergencyWithdrawNFT()`

**Events**
1. `Deposit`
2. `FundingCancelled`
3. `Refunded`
4. `NFTBought`
5. `Voted`
6. `SaleProposalReset`
7. `SaleExecuted`
8. `EmergencyVoted`
9. `EmergencyWithdrawn`
