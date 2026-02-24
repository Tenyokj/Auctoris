import { hre, type HardhatEthers } from "../../test/setup.js";

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

let ethers: HardhatEthers;

async function main() {
  const connection = await hre.network.connect();
  ({ ethers } = connection);

  const [deployer, realD] = await ethers.getSigners();

  const nftName = env("MOCK_NFT_NAME") ?? "FlashAlliance Mock NFT";
  const nftSymbol = env("MOCK_NFT_SYMBOL") ?? "FAMOCK";
  const tokenId = BigInt(env("MOCK_NFT_TOKEN_ID") ?? "1");
  const seller = env("MOCK_NFT_SELLER") ?? realD.address;

  const approveAlliance = boolEnv("APPROVE_ALLIANCE", false);
  const allianceAddress = env("ALLIANCE_ADDRESS");

  if (approveAlliance && !allianceAddress) {
    throw new Error("Set ALLIANCE_ADDRESS when APPROVE_ALLIANCE=true");
  }

  const NFT = await ethers.getContractFactory("ERC721Mock");
  const nft = await NFT.deploy(nftName, nftSymbol);
  await nft.waitForDeployment();

  const nftAddress = await nft.getAddress();

  const mintTx = await nft.mint(seller, tokenId);
  await mintTx.wait();

  if (approveAlliance && allianceAddress) {
    const sellerSigner = await ethers.getSigner(seller);
    const approveTx = await nft.connect(sellerSigner).approve(allianceAddress, tokenId);
    await approveTx.wait();
  }
  
  console.log("Deployer:", deployer.address);
  console.log("ERC721Mock deployed:", nftAddress);
  console.log("Minted token ID:", tokenId.toString());
  console.log("Seller:", seller);

  if (approveAlliance && allianceAddress) {
    console.log("Approved alliance:", allianceAddress);
  }

  console.log("\nUse in dApp NFT Purchase:");
  console.log("NFT address:", nftAddress);
  console.log("Token ID:", tokenId.toString());
  console.log("Seller:", seller);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
