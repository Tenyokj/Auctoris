# AllianceFactory

**Summary**
Factory that deploys `Alliance` instances and keeps an on-chain registry list.

**Role In System**
Entry point for creating new alliances with validated share configuration.

**Key Features**
1. Validates participants/shares length.
2. Validates token address is non-zero.
3. Validates shares sum to 100.
4. Validates quorum and sale-threshold configuration.
5. Sets creator (`msg.sender`) as alliance owner/admin.
6. Stores created alliance in `alliances`.
7. Indexes alliances by admin and participant.

**Main Functions**
1. `createAlliance(...)`
2. `getAllAlliances()`
3. `getAlliancesByAdmin(address)`
4. `getAlliancesByParticipant(address)`
5. `allAlliancesCount()`

**Events**
1. `AllianceCreated`
