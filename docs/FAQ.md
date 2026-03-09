**FAQ**

**Contents**
1. Naming
2. Deployment and Updating
3. Testing
4. Scope

**Naming**
1. Yes, it's correctly called the AlsoSwap Protocol.
2. In DeFi, a DEX is usually called a protocol.

**Deployment and Update**
1. Why does the address change locally: `hardhat node` restarts the state
2. Why does the update fail from the owner: the signer is not the owner of `ProxyAdmin`
3. Why does Hardhat complain about `--proxyAdmin`: env vars are used for the script

**Testing**
1. Is `hardhat node` required for testing: No, `hardhat test` uses the in-process network
2. How to run coverage: `npm run Cover`

**Scope**
1. Is a faucet needed: not required for the DEX core
2. A builder is usually used for the demo version and for onboarding testers