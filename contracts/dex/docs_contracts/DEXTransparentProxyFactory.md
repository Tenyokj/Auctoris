**DEXTransparentProxyFactory**

**Summary**
Deployment helper for `TransparentUpgradeableProxy` + `ProxyAdmin` stacks.

**Role In System**
1. Simplifies scripted deployment of upgradeable modules
2. Emits deployment metadata for ops tracking

**Key Features**
1. Deploys implementation
2. Deploys dedicated ProxyAdmin
3. Deploys proxy with encoded initializer

**Access Control**
Stateless helper, no persistent privileged state.

**Upgradeability**
Non-upgradeable utility contract.
