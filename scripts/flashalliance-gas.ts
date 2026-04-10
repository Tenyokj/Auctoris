import hre from "hardhat";

async function gas(txPromise: Promise<any>): Promise<bigint> {
  const tx = await txPromise;
  const receipt = await tx.wait();
  return receipt.gasUsed as bigint;
}

async function main() {
  const connection = await hre.network.connect();
  const { ethers } = connection;
  const [deployer, admin, alice, bob, carol, seller, buyer] = await ethers.getSigners();

  const TARGET = ethers.parseEther("1000");
  const DAY = 24 * 60 * 60;

  const Token = await ethers.getContractFactory("FATK", deployer);
  const token = await Token.deploy(admin.address);
  await token.waitForDeployment();

  const NFT = await ethers.getContractFactory("ERC721Mock", deployer);
  const nft = await NFT.deploy("MockNFT", "MNFT");
  await nft.waitForDeployment();

  const Alliance = await ethers.getContractFactory("Alliance", deployer);
  const alliance = await Alliance.deploy(
    TARGET,
    7 * DAY,
    [alice.address, bob.address, carol.address],
    [50, 30, 20],
    await token.getAddress(),
    admin.address,
    60,
    80,
    TARGET
  );
  await alliance.waitForDeployment();

  await (await token.connect(admin).mint(alice.address, ethers.parseEther("2000"))).wait();
  await (await token.connect(admin).mint(bob.address, ethers.parseEther("2000"))).wait();
  await (await token.connect(admin).mint(carol.address, ethers.parseEther("2000"))).wait();
  await (await token.connect(admin).mint(buyer.address, ethers.parseEther("5000"))).wait();
  await (await nft.mint(seller.address, 1)).wait();

  await (await token.connect(alice).approve(await alliance.getAddress(), ethers.parseEther("500"))).wait();
  await (await token.connect(bob).approve(await alliance.getAddress(), ethers.parseEther("300"))).wait();
  await (await token.connect(carol).approve(await alliance.getAddress(), ethers.parseEther("200"))).wait();

  const gDepositA = await gas(alliance.connect(alice).deposit(ethers.parseEther("500")));
  const gDepositB = await gas(alliance.connect(bob).deposit(ethers.parseEther("300")));
  const gDepositC = await gas(alliance.connect(carol).deposit(ethers.parseEther("200")));

  await (await nft.connect(seller).approve(await alliance.getAddress(), 1)).wait();
  const now = await connection.networkHelpers.time.latest();
  const acquisitionDeadline = BigInt(now + DAY);
  const saleDeadline = BigInt(now + 2 * DAY);
  const salePrice = ethers.parseEther("1200");

  const gVoteAcquireA = await gas(
    alliance
      .connect(alice)
      .voteToAcquire(await nft.getAddress(), 1, seller.address, TARGET, acquisitionDeadline)
  );
  const gVoteAcquireB = await gas(
    alliance
      .connect(bob)
      .voteToAcquire(await nft.getAddress(), 1, seller.address, TARGET, acquisitionDeadline)
  );
  const gBuyNft = await gas(alliance.connect(carol).buyNFT());

  const gVoteSellA = await gas(alliance.connect(alice).voteToSell(buyer.address, salePrice, saleDeadline));
  const gVoteSellB = await gas(alliance.connect(bob).voteToSell(buyer.address, salePrice, saleDeadline));

  await (await token.connect(buyer).approve(await alliance.getAddress(), salePrice)).wait();
  const gExecuteSale = await gas(alliance.connect(carol).executeSale());
  const gClaimAlice = await gas(alliance.connect(alice).claimProceeds());
  const gClaimBob = await gas(alliance.connect(bob).claimProceeds());
  const gClaimCarol = await gas(alliance.connect(carol).claimProceeds());

  console.log(
    JSON.stringify(
      {
        deposit: {
          aliceFirst: gDepositA.toString(),
          bobSecond: gDepositB.toString(),
          carolThird: gDepositC.toString(),
        },
        acquire: {
          voteFirst: gVoteAcquireA.toString(),
          voteSecond: gVoteAcquireB.toString(),
          buyNFT: gBuyNft.toString(),
        },
        sale: {
          voteFirst: gVoteSellA.toString(),
          voteSecond: gVoteSellB.toString(),
          executeSale: gExecuteSale.toString(),
          claimAlice: gClaimAlice.toString(),
          claimBob: gClaimBob.toString(),
          claimCarol: gClaimCarol.toString(),
        },
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
