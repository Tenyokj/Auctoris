/**
 * @file deploy-proxies.ts
 * @notice Deploys DEX contracts via TransparentUpgradeableProxy (OZ v5).
 * @dev Each proxy owns its own ProxyAdmin. Owner = PROXY_ADMIN_OWNER or deployer.
 * @dev Run with: npx hardhat run scripts/dex/deploy-proxies.ts --network localhost
 */

import { createRequire } from "module";
import hre from "hardhat";
import type { HardhatEthers } from "@nomicfoundation/hardhat-ethers/types";

const require = createRequire(import.meta.url);
const transparentProxyArtifact = require("@openzeppelin/contracts/build/contracts/TransparentUpgradeableProxy.json");

type DeployedProxy = {
  proxyAddress: string;
  implAddress: string;
  proxyAdminAddress: string;
};

type DeploymentSummary = {
  network: string;
  deployer: string;
  proxyAdminOwner: string;
  weth: string;
  poolFactory: DeployedProxy;
  router: DeployedProxy;
  routerV2: DeployedProxy;
  priceOracle: DeployedProxy;
  feeCollector: DeployedProxy;
  flashLoanLimiter: DeployedProxy;
  dexGovernance: DeployedProxy;
};

function getProxyAdminSlot(ethers: HardhatEthers): string {
  const adminSlot = BigInt(ethers.keccak256(ethers.toUtf8Bytes("eip1967.proxy.admin"))) - 1n;
  return ethers.toBeHex(adminSlot, 32);
}

async function readProxyAdmin(ethers: HardhatEthers, proxyAddress: string): Promise<string> {
  const adminSlot = getProxyAdminSlot(ethers);
  const adminStorage = await ethers.provider.getStorage(proxyAddress, adminSlot);
  return ethers.getAddress(ethers.dataSlice(adminStorage, 12));
}

async function deployProxy(
  ethers: HardhatEthers,
  name: string,
  initArgs: unknown[],
  initialOwner: string
): Promise<DeployedProxy> {
  const [deployer] = await ethers.getSigners();

  const implFactory = await ethers.getContractFactory(name, deployer);
  const impl = await implFactory.deploy();
  await impl.waitForDeployment();

  const initData = implFactory.interface.encodeFunctionData("initialize", initArgs);
  const proxyFactory = new ethers.ContractFactory(transparentProxyArtifact.abi, transparentProxyArtifact.bytecode, deployer);
  const proxy = await proxyFactory.deploy(await impl.getAddress(), initialOwner, initData);
  await proxy.waitForDeployment();

  const proxyAddress = await proxy.getAddress();
  const proxyAdminAddress = await readProxyAdmin(ethers, proxyAddress);

  return {
    proxyAddress,
    implAddress: await impl.getAddress(),
    proxyAdminAddress,
  };
}

function resolveNetworkName(chainName: string, chainId: bigint): string {
  if (chainName !== "unknown") return chainName;
  return `chain-${chainId.toString()}`;
}

async function main() {
  const connection = await hre.network.connect();
  const { ethers } = connection;
  const [deployer] = await ethers.getSigners();

  const networkInfo = await ethers.provider.getNetwork();
  const networkName = resolveNetworkName(networkInfo.name, networkInfo.chainId);

  const proxyAdminOwner =
    process.env.PROXY_ADMIN_OWNER && process.env.PROXY_ADMIN_OWNER.trim() !== ""
      ? ethers.getAddress(process.env.PROXY_ADMIN_OWNER)
      : deployer.address;

  const swapFeeBps = process.env.SWAP_FEE_BPS ? BigInt(process.env.SWAP_FEE_BPS) : 30n;
  const protocolFeeBps = process.env.PROTOCOL_FEE_BPS ? BigInt(process.env.PROTOCOL_FEE_BPS) : 5n;
  const minDelaySeconds = process.env.GOV_MIN_DELAY ? BigInt(process.env.GOV_MIN_DELAY) : 3600n;
  const defaultMaxOutBps = process.env.FLASH_DEFAULT_MAX_OUT_BPS ? BigInt(process.env.FLASH_DEFAULT_MAX_OUT_BPS) : 3000n;

  console.log("🚀 Deploying DEX via Transparent Proxies");
  console.log("Network:", networkName);
  console.log("Deployer:", deployer.address);
  console.log("ProxyAdmin owner:", proxyAdminOwner);

  let wethAddress = process.env.WETH_ADDRESS?.trim();
  if (!wethAddress) {
    console.log("No WETH_ADDRESS provided. Deploying MockWETH...");
    const weth = await ethers.deployContract("MockWETH", deployer);
    await weth.waitForDeployment();
    wethAddress = await weth.getAddress();
  }
  wethAddress = ethers.getAddress(wethAddress);

  console.log("WETH:", wethAddress);

  console.log("\n1) Deploying core proxies...");
  const poolFactory = await deployProxy(ethers, "PoolFactory", [deployer.address, wethAddress], proxyAdminOwner);
  const router = await deployProxy(ethers, "Router", [deployer.address, poolFactory.proxyAddress, wethAddress], proxyAdminOwner);
  const routerV2 = await deployProxy(ethers, "RouterV2", [deployer.address, poolFactory.proxyAddress, router.proxyAddress], proxyAdminOwner);
  const priceOracle = await deployProxy(ethers, "PriceOracle", [deployer.address], proxyAdminOwner);
  const feeCollector = await deployProxy(ethers, "FeeCollector", [deployer.address], proxyAdminOwner);
  const flashLoanLimiter = await deployProxy(
    ethers,
    "FlashLoanLimiter",
    [deployer.address, defaultMaxOutBps],
    proxyAdminOwner
  );
  const dexGovernance = await deployProxy(
    ethers,
    "DEXGovernance",
    [deployer.address, poolFactory.proxyAddress, minDelaySeconds],
    proxyAdminOwner
  );

  console.log("\n2) Configuring factory...");
  const factory = await ethers.getContractAt("PoolFactory", poolFactory.proxyAddress, deployer);
  await (await factory.setFeeConfig(swapFeeBps, protocolFeeBps, feeCollector.proxyAddress)).wait();
  await (await factory.setFlashLoanLimiter(flashLoanLimiter.proxyAddress)).wait();

  if ((process.env.TRANSFER_FACTORY_TO_GOVERNANCE ?? "false").toLowerCase() === "true") {
    console.log("Transferring PoolFactory ownership to DEXGovernance...");
    await (await factory.transferOwnership(dexGovernance.proxyAddress)).wait();
  }

  const summary: DeploymentSummary = {
    network: networkName,
    deployer: deployer.address,
    proxyAdminOwner,
    weth: wethAddress,
    poolFactory,
    router,
    routerV2,
    priceOracle,
    feeCollector,
    flashLoanLimiter,
    dexGovernance,
  };

  console.log("\n✅ Deployment summary (copy to .env):");
  console.log(`DEX_WETH=${summary.weth}`);
  console.log(`DEX_FACTORY=${summary.poolFactory.proxyAddress}`);
  console.log(`DEX_ROUTER=${summary.router.proxyAddress}`);
  console.log(`DEX_ROUTER_V2=${summary.routerV2.proxyAddress}`);
  console.log(`DEX_ORACLE=${summary.priceOracle.proxyAddress}`);
  console.log(`DEX_FEE_COLLECTOR=${summary.feeCollector.proxyAddress}`);
  console.log(`DEX_FLASH_LIMITER=${summary.flashLoanLimiter.proxyAddress}`);
  console.log(`DEX_GOVERNANCE=${summary.dexGovernance.proxyAddress}`);

  console.log("\nProxyAdmin per proxy:");
  console.log("PoolFactory:", summary.poolFactory.proxyAdminAddress);
  console.log("Router:", summary.router.proxyAdminAddress);
  console.log("RouterV2:", summary.routerV2.proxyAdminAddress);
  console.log("PriceOracle:", summary.priceOracle.proxyAdminAddress);
  console.log("FeeCollector:", summary.feeCollector.proxyAdminAddress);
  console.log("FlashLoanLimiter:", summary.flashLoanLimiter.proxyAdminAddress);
  console.log("DEXGovernance:", summary.dexGovernance.proxyAdminAddress);

  console.log("\nImplementations:");
  console.log("PoolFactory:", summary.poolFactory.implAddress);
  console.log("Router:", summary.router.implAddress);
  console.log("RouterV2:", summary.routerV2.implAddress);
  console.log("PriceOracle:", summary.priceOracle.implAddress);
  console.log("FeeCollector:", summary.feeCollector.implAddress);
  console.log("FlashLoanLimiter:", summary.flashLoanLimiter.implAddress);
  console.log("DEXGovernance:", summary.dexGovernance.implAddress);

  console.log("\n🎉 DEX deployment complete");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
