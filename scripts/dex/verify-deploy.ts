/**
 * @file verify-deploy.ts
 * @notice Quick post-deploy checks for DEX proxies and wiring.
 * @dev Uses env vars to locate deployed proxies.
 * @dev Run with: npx hardhat run scripts/dex/verify-deploy.ts --network localhost
 */

import hre from "hardhat";

type AddrMap = {
  WETH: string;
  FACTORY: string;
  ROUTER: string;
  ROUTER_V2: string;
  ORACLE: string;
  FEE_COLLECTOR: string;
  FLASH_LIMITER: string;
  GOVERNANCE: string;
};

function getEnv(name: keyof AddrMap): string {
  const v = process.env[`DEX_${name}`] || process.env[name];
  if (!v) {
    throw new Error(`Missing env var DEX_${name} (or ${name})`);
  }
  return v;
}

function normalizeAddress(ethers: any, value: string): string {
  return ethers.getAddress(value.trim().toLowerCase());
}

async function main() {
  const connection = await hre.network.connect();
  const { ethers } = connection;

  const net = await ethers.provider.getNetwork();
  const networkName = net.name === "unknown" ? `chain-${net.chainId.toString()}` : net.name;

  const addrs: AddrMap = {
    WETH: normalizeAddress(ethers, getEnv("WETH")),
    FACTORY: normalizeAddress(ethers, getEnv("FACTORY")),
    ROUTER: normalizeAddress(ethers, getEnv("ROUTER")),
    ROUTER_V2: normalizeAddress(ethers, getEnv("ROUTER_V2")),
    ORACLE: normalizeAddress(ethers, getEnv("ORACLE")),
    FEE_COLLECTOR: normalizeAddress(ethers, getEnv("FEE_COLLECTOR")),
    FLASH_LIMITER: normalizeAddress(ethers, getEnv("FLASH_LIMITER")),
    GOVERNANCE: normalizeAddress(ethers, getEnv("GOVERNANCE")),
  };

  console.log("🔍 Verify DEX Deployment");
  console.log("Network:", networkName);
  console.log("Addresses:", addrs);

  const factory = await ethers.getContractAt("PoolFactory", addrs.FACTORY);
  const router = await ethers.getContractAt("Router", addrs.ROUTER);
  const routerV2 = await ethers.getContractAt("RouterV2", addrs.ROUTER_V2);
  const oracle = await ethers.getContractAt("PriceOracle", addrs.ORACLE);
  const feeCollector = await ethers.getContractAt("FeeCollector", addrs.FEE_COLLECTOR);
  const limiter = await ethers.getContractAt("FlashLoanLimiter", addrs.FLASH_LIMITER);
  const governance = await ethers.getContractAt("DEXGovernance", addrs.GOVERNANCE);

  console.log("\n✅ Wiring checks");
  console.log("Factory.WETH == env WETH:", (await factory.WETH()) === addrs.WETH);
  console.log("Router.factory == Factory:", (await router.factory()) === addrs.FACTORY);
  console.log("Router.WETH == env WETH:", (await router.WETH()) === addrs.WETH);
  console.log("RouterV2.factory == Factory:", (await routerV2.factory()) === addrs.FACTORY);
  console.log("RouterV2.router == Router:", (await routerV2.router()) === addrs.ROUTER);
  console.log("Governance.factory == Factory:", (await governance.factory()) === addrs.FACTORY);

  console.log("\n✅ Factory config");
  console.log("swapFeeBps:", (await factory.swapFeeBps()).toString());
  console.log("protocolFeeBps:", (await factory.protocolFeeBps()).toString());
  console.log("feeReceiver:", await factory.feeReceiver());
  console.log("flashLoanLimiter:", await factory.flashLoanLimiter());
  console.log("allPoolsLength:", (await factory.allPoolsLength()).toString());

  console.log("\n✅ Pause status");
  console.log("PoolFactory paused:", await factory.paused());
  console.log("Router paused:", await router.paused());
  console.log("RouterV2 paused:", await routerV2.paused());
  console.log("PriceOracle paused:", await oracle.paused());
  console.log("FeeCollector paused:", await feeCollector.paused());
  console.log("FlashLoanLimiter paused:", await limiter.paused());
  console.log("DEXGovernance paused:", await governance.paused());

  console.log("\n✅ Extension params");
  console.log("FlashLoanLimiter.defaultMaxOutBps:", (await limiter.defaultMaxOutBps()).toString());
  console.log("Governance.minDelay:", (await governance.minDelay()).toString());

  console.log("\n🎉 Verification complete");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
