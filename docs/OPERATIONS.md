**Operations Guide**

**Contents**
1. Daily Checks
2. Incident Flow
3. Pause and Recovery
4. Monitoring Signals
5. Operational Checklist

**Daily Checks**
1. Confirm core proxies are reachable
2. Confirm factory/router pause status
3. Confirm fee receiver and fee bps values
4. Confirm oracle observations are updating

**Incident Flow**
1. Detect abnormal swaps, fee behavior, or failed tx spikes
2. Pause affected modules (`Router`, `PoolFactory`, governance paths)
3. Identify root cause and impacted contracts
4. Patch and redeploy implementation
5. Upgrade proxy and run post-upgrade checks
6. Unpause and monitor recovery window

**Pause and Recovery**
1. Pause first, then communicate, then patch
2. Keep treasury withdrawal path for emergency operations
3. Resume in stages: factory/router first, then optional modules

**Monitoring Signals**
1. Pool reserve drift vs expected invariant behavior
2. Failed transaction ratio on router swap paths
3. Unexpected fee spikes or fee receiver changes
4. Governance queue with suspicious admin actions

**Operational Checklist**
1. Run deploy verification script after each change
2. Re-run test suite before every upgrade
3. Record proxy, implementation, and ProxyAdmin addresses
4. Keep upgrade logs and tx hashes in release notes
