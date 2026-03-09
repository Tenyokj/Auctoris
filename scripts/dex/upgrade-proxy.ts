/**
 * @file upgrade-proxy.ts
 * @notice Upgrades a single TransparentUpgradeableProxy via its ProxyAdmin.
 * @dev Uses OZ v5 ProxyAdmin.upgradeAndCall. Reads admin from EIP-1967 slot if not provided.
 * @dev Run with: npx hardhat run scripts/dex/upgrade-proxy.ts --network localhost -- --proxy <addr> --impl <ContractName>
 */

import { createRequire } from "module";
import hre from "hardhat";
import type { HardhatEthers } from "@nomicfoundation/hardhat-ethers/types";

const require = createRequire(import.meta.url);
const proxyAdminArtifact = require("@openzeppelin/contracts/build/contracts/ProxyAdmin.json");

function parseArgs() {
  const proxyAdminAddress = process.env.PROXY_ADMIN;
  const proxyAddress = process.env.PROXY;
  const implName = process.env.IMPL;
  const call = process.env.CALL;
  const rawArgs = process.env.ARGS;
  const gasLimit = process.env.GAS_LIMIT;

  if (!proxyAddress || !implName) {
    console.error(`
Usage:
  PROXY=<proxy> IMPL=<impl> [PROXY_ADMIN=<admin>] [CALL=<fn>] [ARGS='[...]'] [GAS_LIMIT=<num>] \\
  npx hardhat run scripts/dex/upgrade-proxy.ts --network <network>

Example:
  PROXY_ADMIN=0xProxyAdmin PROXY=0xProxy IMPL=RouterV3 \\
  npx hardhat run scripts/dex/upgrade-proxy.ts --network localhost
`);
    process.exit(1);
  }

  return {
    proxyAdminAddress,
    proxyAddress,
    implName,
    call,
    args: rawArgs ? JSON.parse(rawArgs) : [],
    gasLimit: gasLimit ? BigInt(gasLimit) : undefined,
  };
}

function eip1967Slot(ethers: HardhatEthers, label: "admin" | "implementation"): string {
  const key = `eip1967.proxy.${label}`;
  return ethers.toBeHex(BigInt(ethers.keccak256(ethers.toUtf8Bytes(key))) - 1n, 32);
}

async function readProxyStructure(ethers: HardhatEthers, proxyAddress: string) {
  const [adminStorage, implStorage] = await Promise.all([
    ethers.provider.getStorage(proxyAddress, eip1967Slot(ethers, "admin")),
    ethers.provider.getStorage(proxyAddress, eip1967Slot(ethers, "implementation")),
  ]);

  return {
    adminFromSlot: ethers.getAddress(ethers.dataSlice(adminStorage, 12)),
    implFromSlot: ethers.getAddress(ethers.dataSlice(implStorage, 12)),
  };
}

async function main() {
  const args = parseArgs();
  const connection = await hre.network.connect();
  const { ethers } = connection;
  const [deployer] = await ethers.getSigners();

  const { adminFromSlot, implFromSlot } = await readProxyStructure(ethers, args.proxyAddress);
  const effectiveProxyAdmin = args.proxyAdminAddress
    ? ethers.getAddress(args.proxyAdminAddress)
    : adminFromSlot;

  const net = await ethers.provider.getNetwork();
  const networkName = net.name === "unknown" ? `chain-${net.chainId.toString()}` : net.name;

  console.log("🚀 Starting proxy upgrade");
  console.log("Network:", networkName);
  console.log("Deployer:", deployer.address);
  console.log("Proxy:", args.proxyAddress);
  console.log("ProxyAdmin:", effectiveProxyAdmin);
  console.log("Current implementation:", implFromSlot);
  console.log("Target implementation contract:", args.implName);

  const proxyAdmin = new ethers.Contract(effectiveProxyAdmin, proxyAdminArtifact.abi, deployer);
  const owner = await proxyAdmin.owner();
  if (ethers.getAddress(owner) !== ethers.getAddress(deployer.address)) {
    throw new Error(`Deployer ${deployer.address} is not ProxyAdmin owner ${owner}`);
  }

  const implFactory = await ethers.getContractFactory(args.implName, deployer);
  const newImpl = await implFactory.deploy();
  await newImpl.waitForDeployment();
  const newImplAddress = await newImpl.getAddress();

  let callData = "0x";
  if (args.call) {
    callData = implFactory.interface.encodeFunctionData(args.call, args.args);
  }

  const txOptions: Record<string, bigint> = {};
  if (args.gasLimit) txOptions.gasLimit = args.gasLimit;

  const tx = await proxyAdmin.upgradeAndCall(args.proxyAddress, newImplAddress, callData, txOptions);
  console.log("⏳ Upgrade tx:", tx.hash);
  const receipt = await tx.wait();
  console.log("✅ Mined in block:", receipt?.blockNumber);

  const { implFromSlot: upgradedImpl } = await readProxyStructure(ethers, args.proxyAddress);
  if (ethers.getAddress(upgradedImpl) !== ethers.getAddress(newImplAddress)) {
    throw new Error(`Upgrade verification failed: expected ${newImplAddress}, got ${upgradedImpl}`);
  }

  console.log("🎉 Upgrade successful");
  console.log(JSON.stringify({
    network: networkName,
    proxy: args.proxyAddress,
    proxyAdmin: effectiveProxyAdmin,
    oldImplementation: implFromSlot,
    newImplementation: upgradedImpl,
    transactionHash: tx.hash,
    postUpgradeCall: args.call ?? null,
    callArgs: args.args,
  }, null, 2));
}

main().catch((error) => {
  console.error("Upgrade failed:", error);
  process.exit(1);
});
