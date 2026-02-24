import { promises as fs } from "node:fs";
import path from "node:path";
import { hre, type HardhatEthers } from "../../test/setup.js";
import { fileURLToPath } from "node:url";

function env(name: string): string | undefined {
  const value = process.env[name];
  if (!value) return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function boolEnv(name: string, defaultValue = false): boolean {
  const value = env(name);
  if (!value) return defaultValue;
  return ["1", "true", "yes", "on"].includes(value.toLowerCase());
}

function parseShares(raw: string) {
  return raw
    .split(",")
    .map((x) => x.trim())
    .filter(Boolean)
    .map((x) => BigInt(x));
}

let ethers: HardhatEthers;

async function main() {
  const connection = await hre.network.connect();
  ({ ethers } = connection);

  const signers = await ethers.getSigners();
  if (signers.length < 7) {
    throw new Error("Need at least 7 local signers");
  }

  const deployer = signers[0];
  const tokenOwner = signers[0];
  const participants = [signers[1], signers[2], signers[3]];
  const seller = signers[4];

  const shares = parseShares(env("SHARES") ?? "50,30,20");
  if (shares.length !== participants.length) {
    throw new Error("SHARES length must match participant count (3)");
  }
  const sumShares = shares.reduce((acc, cur) => acc + cur, 0n);
  if (sumShares !== 100n) {
    throw new Error(`SHARES must sum to 100, got ${sumShares.toString()}`);
  }

  const targetTokens = env("TARGET_TOKENS") ?? "50000";
  const deadlineSeconds = BigInt(env("DEADLINE_SECONDS") ?? "604800");
  const mintPerParticipant = env("MINT_PER_PARTICIPANT") ?? "200000";
  const faucetSupply = env("FAUCET_SUPPLY") ?? "10000000";
  const faucetClaimAmount = env("FAUCET_CLAIM_AMOUNT") ?? "10000";
  const faucetCooldown = BigInt(env("FAUCET_COOLDOWN_SECONDS") ?? "86400");
  const seedDeposits = boolEnv("SEED_DEPOSITS", false);
  const createMockNft = boolEnv("CREATE_MOCK_NFT", true);
  const approveMockNft = boolEnv("APPROVE_MOCK_NFT", true);
  const deployFaucet = boolEnv("DEPLOY_FAUCET", true);
  const autoWriteFrontendEnv = boolEnv("WRITE_FRONTEND_ENV", true);

  console.log("Deployer:", deployer.address);

  const Token = await ethers.getContractFactory("FATK");
  const token = await Token.deploy(tokenOwner.address);
  await token.waitForDeployment();

  const tokenAddress = await token.getAddress();
  console.log("TenyokjToken:", tokenAddress);

  const Factory = await ethers.getContractFactory("AllianceFactory");
  const factory = await Factory.deploy();
  await factory.waitForDeployment();

  const factoryAddress = await factory.getAddress();
  console.log("AllianceFactory:", factoryAddress);

  let faucetAddress = "";
  if (deployFaucet) {
    const Faucet = await ethers.getContractFactory("FATKFaucet");
    const faucet = await Faucet.deploy(
      tokenAddress,
      deployer.address,
      ethers.parseUnits(faucetClaimAmount, 18),
      faucetCooldown
    );
    await faucet.waitForDeployment();
    faucetAddress = await faucet.getAddress();
    console.log("FATKFaucet:", faucetAddress);
  }

  const mintUnits = ethers.parseUnits(mintPerParticipant, 18);
  for (const p of participants) {
    await (await token.connect(tokenOwner).mint(p.address, mintUnits)).wait();
  }
  console.log(`Minted ${mintPerParticipant} FATK to each participant`);

  if (deployFaucet && faucetAddress) {
    const faucetSupplyUnits = ethers.parseUnits(faucetSupply, 18);
    await (await token.connect(tokenOwner).mint(faucetAddress, faucetSupplyUnits)).wait();
    console.log(`Minted ${faucetSupply} FATK to faucet liquidity`);
  }

  const targetUnits = ethers.parseUnits(targetTokens, 18);
  const createTx = await factory.connect(deployer).createAlliance(
    targetUnits,
    deadlineSeconds,
    participants.map((p) => p.address),
    shares,
    tokenAddress
  );
  await createTx.wait();

  const alliances = (await factory.getAllAlliances()) as string[];
  const allianceAddress = alliances[alliances.length - 1];
  console.log("Alliance created:", allianceAddress);

  const alliance = await ethers.getContractAt("Alliance", allianceAddress);

  for (const p of participants) {
    await (await token.connect(p).approve(allianceAddress, mintUnits)).wait();
  }
  console.log("Participants approved alliance for spending FATK");

  if (seedDeposits) {
    for (let i = 0; i < participants.length; i += 1) {
      const amount = (targetUnits * shares[i]) / 100n;
      await (await alliance.connect(participants[i]).deposit(amount)).wait();
    }
    console.log("Seed deposits completed up to target");
  }

  let nftAddress = "";
  let nftTokenId = "";
  if (createMockNft) {
    const nftName = env("MOCK_NFT_NAME") ?? "FlashAlliance Mock NFT";
    const nftSymbol = env("MOCK_NFT_SYMBOL") ?? "FAMOCK";
    const tokenId = BigInt(env("MOCK_NFT_TOKEN_ID") ?? "1");

    const NFT = await ethers.getContractFactory("ERC721Mock");
    const nft = await NFT.deploy(nftName, nftSymbol);
    await nft.waitForDeployment();

    nftAddress = await nft.getAddress();
    nftTokenId = tokenId.toString();

    await (await nft.mint(seller.address, tokenId)).wait();

    if (approveMockNft) {
      await (await nft.connect(seller).approve(allianceAddress, tokenId)).wait();
    }

    console.log("Mock NFT:", nftAddress);
    console.log("Mock NFT tokenId:", nftTokenId);
    console.log("Mock NFT seller:", seller.address);
    if (approveMockNft) {
      console.log("Mock NFT approved for alliance");
    }
  }

  if (autoWriteFrontendEnv) {
    const scriptDir = path.dirname(fileURLToPath(import.meta.url));
    const defaultFrontendEnvPath = path.resolve(scriptDir, "../../../.env.local");
    const envPath = env("FRONTEND_ENV_PATH") ?? defaultFrontendEnvPath;
    const envContent = [
      `NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545`,
      `NEXT_PUBLIC_TOKEN_ADDRESS=${tokenAddress}`,
      `NEXT_PUBLIC_FACTORY_ADDRESS=${factoryAddress}`,
      `NEXT_PUBLIC_FAUCET_ADDRESS=${faucetAddress || "0x0000000000000000000000000000000000000000"}`
    ].join("\n");
    await fs.writeFile(envPath, `${envContent}\n`, "utf8");
    console.log("Updated frontend env:", envPath);
  }

  console.log("\n=== Bootstrap Summary ===");
  console.log("Factory:", factoryAddress);
  console.log("Token:", tokenAddress);
  if (deployFaucet) {
    console.log("Faucet:", faucetAddress);
  }
  console.log("Alliance:", allianceAddress);
  console.log("Participants:", participants.map((p) => p.address).join(", "));
  if (createMockNft) {
    console.log("NFT:", nftAddress);
    console.log("NFT tokenId:", nftTokenId);
    console.log("NFT seller:", seller.address);
  }
  console.log("=========================\n");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
