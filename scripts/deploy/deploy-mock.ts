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

  const [deployer, fallbackSeller] = await ethers.getSigners();

  const nftName = env("MOCK_NFT_NAME") ?? "FlashAlliance Mock NFT";
  const nftSymbol = env("MOCK_NFT_SYMBOL") ?? "FAMOCK";
  const tokenId = BigInt(env("MOCK_NFT_TOKEN_ID") ?? "1");
  const seller = env("MOCK_NFT_SELLER") ?? fallbackSeller.address;

  const approveAlliance = boolEnv("APPROVE_ALLIANCE", false);
  const allianceAddress = env("ALLIANCE_ADDRESS");
  if (approveAlliance && !allianceAddress) {
    throw new Error("Set ALLIANCE_ADDRESS when APPROVE_ALLIANCE=true");
  }

  const NFT = await ethers.getContractFactory("ERC721Mock");
  const nft = await NFT.deploy(nftName, nftSymbol);
  await nft.waitForDeployment();

  const nftAddress = await nft.getAddress();
  await (await nft.mint(seller, tokenId)).wait();

  if (approveAlliance && allianceAddress) {
    const sellerSigner = await ethers.getSigner(seller);
    await (await nft.connect(sellerSigner).approve(allianceAddress, tokenId)).wait();
  }

  console.log("Deployer:", deployer.address);
  console.log("ERC721Mock deployed:", nftAddress);
  console.log("Minted token ID:", tokenId.toString());
  console.log("Seller:", seller);
  if (approveAlliance && allianceAddress) {
    console.log("Approved alliance:", allianceAddress);
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
