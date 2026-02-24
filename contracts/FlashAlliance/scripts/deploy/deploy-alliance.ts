import { hre, type HardhatEthers } from "../../test/setup.js";


function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim() === "") {
    throw new Error(`Missing env var: ${name}`);
  }
  return value;
}

let ethers: HardhatEthers;
async function main() {
    const connection = await hre.network.connect();
    ({ ethers } = connection);

  const [deployer] = await ethers.getSigners();

  const tokenOwner = requireEnv("TOKEN_OWNER");

  console.log("Deployer:", deployer.address);
  console.log("Token owner:", tokenOwner);

  const Token = await ethers.getContractFactory("FATK");
  const token = await Token.deploy(tokenOwner);
  await token.waitForDeployment();

  const Factory = await ethers.getContractFactory("AllianceFactory");
  const factory = await Factory.deploy();
  await factory.waitForDeployment();

  const tokenAddress = await token.getAddress();
  const factoryAddress = await factory.getAddress();

  console.log("FATK deployed:", tokenAddress);
  console.log("AllianceFactory deployed:", factoryAddress);

  // Optional one-shot sample alliance deployment
  // Set CREATE_SAMPLE_ALLIANCE=true and pass SAMPLE_* env vars.
  if (process.env.CREATE_SAMPLE_ALLIANCE === "true") {
    const sampleToken = process.env.SAMPLE_TOKEN ?? tokenAddress;
    const targetPrice = requireEnv("SAMPLE_TARGET_PRICE_WEI");
    const deadlineSeconds = requireEnv("SAMPLE_DEADLINE_SECONDS");
    const participantsRaw = requireEnv("SAMPLE_PARTICIPANTS");
    const sharesRaw = requireEnv("SAMPLE_SHARES");

    const participants = participantsRaw.split(",").map((x) => x.trim());
    const shares = sharesRaw.split(",").map((x) => BigInt(x.trim()));

    if (participants.length !== shares.length) {
      throw new Error("SAMPLE_PARTICIPANTS and SAMPLE_SHARES length mismatch");
    }

    const tx = await factory.createAlliance(
      BigInt(targetPrice),
      BigInt(deadlineSeconds),
      participants,
      shares,
      sampleToken
    );
    const receipt = await tx.wait();

    console.log("Sample alliance created. Tx:", receipt?.hash);
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
