import { hre, type HardhatEthers } from "../../test/setup.js";

function env(name: string): string | undefined {
  const value = process.env[name];
  if (!value) return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function requireEnv(name: string): string {
  const value = env(name);
  if (!value) {
    throw new Error(`Missing env var: ${name}`);
  }
  return value;
}

function boolEnv(name: string, defaultValue = false): boolean {
  const value = env(name);
  if (!value) return defaultValue;
  return ["1", "true", "yes", "on"].includes(value.toLowerCase());
}

let ethers: HardhatEthers;

async function main() {
  const connection = await hre.network.connect();
  ({ ethers } = connection);

  const [deployer] = await ethers.getSigners();

  const tokenAddress = requireEnv("TOKEN_ADDRESS");
  const faucetOwner = env("FAUCET_OWNER") ?? deployer.address;
  const claimAmount = ethers.parseUnits(env("FAUCET_CLAIM_AMOUNT") ?? "1000", 18);
  const cooldown = BigInt(env("FAUCET_COOLDOWN_SEC") ?? "86400");

  const tokenCode = await ethers.provider.getCode(tokenAddress);
  if (tokenCode === "0x") {
    throw new Error(`No contract code at TOKEN_ADDRESS: ${tokenAddress}`);
  }

  const token = await ethers.getContractAt("FATK", tokenAddress);
  const Faucet = await ethers.getContractFactory("FATKFaucet");
  const faucet = await Faucet.deploy(tokenAddress, faucetOwner, claimAmount, cooldown);
  await faucet.waitForDeployment();

  const faucetAddress = await faucet.getAddress();

  const mintLiquidity = boolEnv("MINT_FAUCET_LIQUIDITY", false);
  if (mintLiquidity) {
    const liquidityAmount = ethers.parseUnits(env("FAUCET_LIQUIDITY_AMOUNT") ?? "1000000", 18);
    const mintTx = await token.mint(faucetAddress, liquidityAmount);
    await mintTx.wait();
    console.log(`Minted liquidity to faucet: ${ethers.formatUnits(liquidityAmount, 18)} FATK`);
  }

  console.log("Deployer:", deployer.address);
  console.log("Token:", tokenAddress);
  console.log("Faucet owner:", faucetOwner);
  console.log("Claim amount:", ethers.formatUnits(claimAmount, 18), "FATK");
  console.log("Cooldown (sec):", cooldown.toString());
  console.log("FATKFaucet deployed:", faucetAddress);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
