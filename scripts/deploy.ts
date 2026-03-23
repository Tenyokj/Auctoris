import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";

import { verifyContract } from "@nomicfoundation/hardhat-verify/verify";
import { formatUnits, getCreateAddress, isAddress, parseUnits } from "ethers";
import hre from "hardhat";

const TOKEN_DECIMALS = 18;
const TOTAL_SUPPLY = 167_000_000_000n * 10n ** BigInt(TOKEN_DECIMALS);
const LIQUIDITY_ALLOCATION = (TOTAL_SUPPLY * 60n) / 100n;
const TEAM_ALLOCATION = (TOTAL_SUPPLY * 10n) / 100n;
const AIRDROP_ALLOCATION = (TOTAL_SUPPLY * 30n) / 100n;
const LOCAL_NETWORKS = new Set(["default", "hardhat", "localhost"]);

type DeployConfig = {
  liquidityWallet: string;
  teamWallet: string;
  airdropOwner: string;
  amountPerUser: bigint;
  maxUsers: bigint;
  deployClaimCaller: boolean;
  verifyOnDeploy: boolean;
  verifyDelayMs: number;
};

function fail(message: string): never {
  throw new Error(message);
}

function requireAddress(name: string, value: string | undefined): string {
  const resolved = value?.trim();

  if (resolved === undefined || resolved === "") {
    fail(`${name} is required`);
  }

  if (!isAddress(resolved)) {
    fail(`${name} must be a valid address`);
  }

  return resolved;
}

function resolveAddress(
  name: string,
  value: string | undefined,
  fallback: string,
): string {
  const resolved = value?.trim() || fallback;

  if (!isAddress(resolved)) {
    fail(`${name} must be a valid address`);
  }

  return resolved;
}

function parsePositiveBigInt(
  name: string,
  value: string | undefined,
  fallback?: string,
): bigint {
  const raw = value?.trim() || fallback;

  if (raw === undefined || raw === "") {
    fail(`${name} is required`);
  }

  if (!/^\d+$/.test(raw)) {
    fail(`${name} must be a positive integer`);
  }

  const parsed = BigInt(raw);

  if (parsed <= 0n) {
    fail(`${name} must be greater than zero`);
  }

  return parsed;
}

function parseTokenAmount(
  name: string,
  value: string | undefined,
  fallback?: string,
  options: { allowZero?: boolean } = {},
): bigint {
  const raw = value?.trim() || fallback;

  if (raw === undefined || raw === "") {
    fail(`${name} is required`);
  }

  let parsed: bigint;

  try {
    parsed = parseUnits(raw, TOKEN_DECIMALS);
  } catch {
    fail(`${name} must be a valid decimal token amount`);
  }

  if (parsed < 0n) {
    fail(`${name} must not be negative`);
  }

  if (!options.allowZero && parsed === 0n) {
    fail(`${name} must be greater than zero`);
  }

  return parsed;
}

function parseBoolean(value: string | undefined, defaultValue: boolean): boolean {
  if (value === undefined || value.trim() === "") {
    return defaultValue;
  }

  const normalized = value.trim().toLowerCase();

  if (["1", "true", "yes", "y"].includes(normalized)) {
    return true;
  }

  if (["0", "false", "no", "n"].includes(normalized)) {
    return false;
  }

  fail(`Invalid boolean value: ${value}`);
}

function parseNonNegativeInteger(
  name: string,
  value: string | undefined,
  fallback: number,
): number {
  const raw = value?.trim();

  if (raw === undefined || raw === "") {
    return fallback;
  }

  if (!/^\d+$/.test(raw)) {
    fail(`${name} must be a non-negative integer`);
  }

  return Number(raw);
}

function formatToken(amount: bigint): string {
  return formatUnits(amount, TOKEN_DECIMALS);
}

function buildConfig(networkName: string, deployer: string): DeployConfig {
  const isLocal = LOCAL_NETWORKS.has(networkName);
  const hasEtherscanApiKey =
    process.env.ETHERSCAN_API_KEY !== undefined &&
    process.env.ETHERSCAN_API_KEY.trim() !== "";

  const liquidityWallet = isLocal
    ? resolveAddress("LIQUIDITY_WALLET", process.env.LIQUIDITY_WALLET, deployer)
    : requireAddress("LIQUIDITY_WALLET", process.env.LIQUIDITY_WALLET);

  const teamWallet = isLocal
    ? resolveAddress("TEAM_WALLET", process.env.TEAM_WALLET, deployer)
    : requireAddress("TEAM_WALLET", process.env.TEAM_WALLET);

  const airdropOwner = resolveAddress(
    "AIRDROP_OWNER",
    process.env.AIRDROP_OWNER,
    deployer,
  );

  const amountPerUser = parseTokenAmount(
    "AIRDROP_AMOUNT_PER_USER",
    process.env.AIRDROP_AMOUNT_PER_USER,
    isLocal ? "100" : undefined,
  );

  const maxUsers = parsePositiveBigInt(
    "AIRDROP_MAX_USERS",
    process.env.AIRDROP_MAX_USERS,
    isLocal ? "1000" : undefined,
  );

  return {
    liquidityWallet,
    teamWallet,
    airdropOwner,
    amountPerUser,
    maxUsers,
    deployClaimCaller: parseBoolean(process.env.DEPLOY_CLAIM_CALLER, false),
    verifyOnDeploy: !isLocal && parseBoolean(process.env.VERIFY_ON_DEPLOY, hasEtherscanApiKey),
    verifyDelayMs: parseNonNegativeInteger("VERIFY_DELAY_MS", process.env.VERIFY_DELAY_MS, 30_000),
  };
}

async function saveDeployment(networkName: string, payload: unknown): Promise<string> {
  const deploymentsDir = join(process.cwd(), "deployments");
  const filePath = join(deploymentsDir, `${networkName}.json`);

  await mkdir(deploymentsDir, { recursive: true });
  await writeFile(filePath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");

  return filePath;
}

async function verifyDeployedContract(
  address: string,
  contract: string,
  constructorArgs: unknown[],
): Promise<boolean> {
  return verifyContract(
    {
      address,
      contract,
      constructorArgs,
      provider: "etherscan",
    },
    hre,
  );
}

async function main() {
  const connection = await hre.network.connect();
  const { ethers, networkName } = connection;
  const [deployer] = await ethers.getSigners();
  const providerNetwork = await ethers.provider.getNetwork();

  const config = buildConfig(networkName, deployer.address);
  const plannedClaimAmount = config.amountPerUser * config.maxUsers;
  const deployerNonce = await deployer.getNonce("pending");
  const predictedAirdropAddress = getCreateAddress({
    from: deployer.address,
    nonce: BigInt(deployerNonce + 1),
  });

  console.log(`Network: ${networkName} (${providerNetwork.chainId})`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Liquidity wallet: ${config.liquidityWallet}`);
  console.log(`Team wallet: ${config.teamWallet}`);
  console.log(`Airdrop owner: ${config.airdropOwner}`);
  console.log(`Predicted airdrop address: ${predictedAirdropAddress}`);
  console.log(`Airdrop amount per user: ${formatToken(config.amountPerUser)} TENJI`);
  console.log(`Airdrop max users: ${config.maxUsers}`);
  console.log(`Planned claim amount: ${formatToken(plannedClaimAmount)} TENJI`);
  console.log(`Airdrop reserve in contract: ${formatToken(AIRDROP_ALLOCATION)} TENJI`);
  console.log(`Verify on deploy: ${config.verifyOnDeploy ? "enabled" : "disabled"}`);

  if (plannedClaimAmount > AIRDROP_ALLOCATION) {
    fail(
      `Planned claim amount exceeds the 30% airdrop reserve (${formatToken(AIRDROP_ALLOCATION)} TENJI)`,
    );
  }

  if (plannedClaimAmount < AIRDROP_ALLOCATION) {
    console.log(
      `Warning: claim configuration uses ${formatToken(plannedClaimAmount)} TENJI out of ${formatToken(AIRDROP_ALLOCATION)} TENJI reserved for the airdrop.`,
    );
  }

  const token = await ethers.deployContract(
    "TenjiCoin",
    [
      config.liquidityWallet,
      config.teamWallet,
      predictedAirdropAddress,
    ],
    deployer,
  );
  await token.waitForDeployment();

  const tokenAddress = await token.getAddress();
  console.log(`TenjiCoin deployed: ${tokenAddress}`);

  const airdrop = await ethers.deployContract(
    "TenjiAirdrop",
    [
      tokenAddress,
      config.amountPerUser,
      config.maxUsers,
      config.airdropOwner,
    ],
    deployer,
  );
  await airdrop.waitForDeployment();

  const airdropAddress = await airdrop.getAddress();
  console.log(`TenjiAirdrop deployed: ${airdropAddress}`);

  if (airdropAddress.toLowerCase() !== predictedAirdropAddress.toLowerCase()) {
    fail("Predicted airdrop address does not match deployed TenjiAirdrop address");
  }

  let claimCallerAddress: string | null = null;

  if (config.deployClaimCaller) {
    const claimCaller = await ethers.deployContract("AirdropClaimCaller", [], deployer);
    await claimCaller.waitForDeployment();
    claimCallerAddress = await claimCaller.getAddress();
    console.log(`AirdropClaimCaller deployed: ${claimCallerAddress}`);
  }

  const airdropContractBalance = await token.balanceOf(airdropAddress);
  let tokenVerified = false;
  let airdropVerified = false;
  let claimCallerVerified = false;

  if (config.verifyOnDeploy) {
    if (
      process.env.ETHERSCAN_API_KEY === undefined ||
      process.env.ETHERSCAN_API_KEY.trim() === ""
    ) {
      fail("VERIFY_ON_DEPLOY is enabled but ETHERSCAN_API_KEY is missing");
    }

    if (config.verifyDelayMs > 0) {
      console.log(`Waiting ${config.verifyDelayMs}ms before verification...`);
      await new Promise((resolve) => setTimeout(resolve, config.verifyDelayMs));
    }

    tokenVerified = await verifyDeployedContract(
      tokenAddress,
      "contracts/TenjiCoin.sol:TenjiCoin",
      [
        config.liquidityWallet,
        config.teamWallet,
        predictedAirdropAddress,
      ],
    );
    console.log(`TenjiCoin verification: ${tokenVerified ? "ok" : "failed"}`);

    airdropVerified = await verifyDeployedContract(
      airdropAddress,
      "contracts/TenjiAirdrop.sol:TenjiAirdrop",
      [
        tokenAddress,
        config.amountPerUser,
        config.maxUsers,
        config.airdropOwner,
      ],
    );
    console.log(`TenjiAirdrop verification: ${airdropVerified ? "ok" : "failed"}`);

    if (claimCallerAddress !== null) {
      claimCallerVerified = await verifyDeployedContract(
        claimCallerAddress,
        "contracts/AirdropClaimCaller.sol:AirdropClaimCaller",
        [],
      );
      console.log(
        `AirdropClaimCaller verification: ${claimCallerVerified ? "ok" : "failed"}`,
      );
    }
  }

  const deploymentFile = await saveDeployment(networkName, {
    timestamp: new Date().toISOString(),
    network: networkName,
    chainId: providerNetwork.chainId.toString(),
    deployer: deployer.address,
    token: {
      address: tokenAddress,
      totalSupply: TOTAL_SUPPLY.toString(),
      liquidityWallet: config.liquidityWallet,
      liquidityAllocation: LIQUIDITY_ALLOCATION.toString(),
      teamWallet: config.teamWallet,
      teamAllocation: TEAM_ALLOCATION.toString(),
      predictedAirdropAddress,
      airdropAllocation: AIRDROP_ALLOCATION.toString(),
    },
    airdrop: {
      address: airdropAddress,
      owner: config.airdropOwner,
      amountPerUser: config.amountPerUser.toString(),
      maxUsers: config.maxUsers.toString(),
      plannedClaimAmount: plannedClaimAmount.toString(),
      balance: airdropContractBalance.toString(),
    },
    claimCaller: claimCallerAddress,
    verification: {
      enabled: config.verifyOnDeploy,
      tokenVerified,
      airdropVerified,
      claimCallerVerified,
    },
  });

  console.log("=== SUMMARY ===");
  console.log(`Token: ${tokenAddress}`);
  console.log(`Airdrop: ${airdropAddress}`);
  console.log(`ClaimCaller: ${claimCallerAddress ?? "not deployed"}`);
  console.log(`Funding: minted directly to TenjiAirdrop (${formatToken(airdropContractBalance)} TENJI)`);
  console.log(
    `Verification: ${config.verifyOnDeploy ? `token=${tokenVerified}, airdrop=${airdropVerified}, claimCaller=${claimCallerVerified}` : "skipped"}`,
  );
  console.log(`Deployment saved to: ${deploymentFile}`);
}

main().catch((error: unknown) => {
  if (error instanceof Error) {
    console.error(error.message);
  } else {
    console.error(error);
  }

  process.exitCode = 1;
});
