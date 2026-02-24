# AllianceFactory

**Summary**
Factory that deploys `Alliance` instances and keeps an on-chain registry list.

**Role In System**
Entry point for creating new alliances with validated share configuration.

**Key Features**
1. Validates participants/shares length.
2. Validates token address is non-zero.
3. Validates shares sum to 100.
4. Sets creator (`msg.sender`) as alliance owner/admin.
5. Stores created alliance in `alliances`.

**Main Functions**
1. `createAlliance(...)`
2. `getAllAlliances()`

**Events**
1. `AllianceCreated`
