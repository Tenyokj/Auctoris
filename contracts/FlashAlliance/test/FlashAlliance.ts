import {
  hre,
  expect,
  type HardhatEthers,
  type NetworkHelpers,
} from "./setup.js";

describe("FlashAlliance (Ownable)", function () {
  let ethers: HardhatEthers;
  let networkHelpers: NetworkHelpers;
  const TARGET = BigInt("1000000000000000000000"); // 1000 ether

  beforeEach(async function () {
    const connection = await hre.network.connect();
    ({ ethers, networkHelpers } = connection);
  })

  const DAY = 24 * 60 * 60;
 

  async function deploy() {
    const [deployer, admin, outsider, alice, bob, carol, seller, buyer, altBuyer] =
      await ethers.getSigners();

    const Token = await ethers.getContractFactory("FATK", deployer);
    const token = await Token.deploy(deployer.address);
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
      admin.address
    );
    await alliance.waitForDeployment();

    await (await token.mint(alice.address, ethers.parseEther("2000"))).wait();
    await (await token.mint(bob.address, ethers.parseEther("2000"))).wait();
    await (await token.mint(carol.address, ethers.parseEther("2000"))).wait();
    await (await token.mint(buyer.address, ethers.parseEther("5000"))).wait();
    await (await token.mint(altBuyer.address, ethers.parseEther("5000"))).wait();

    await (await nft.mint(seller.address, 1)).wait();
    await (await nft.mint(seller.address, 2)).wait();

    return { deployer, admin, outsider, alice, bob, carol, seller, buyer, altBuyer, token, nft, alliance };
  }

  async function approveAndDeposit(token: any, alliance: any, user: any, amount: bigint) {
    await (await token.connect(user).approve(await alliance.getAddress(), amount)).wait();
    await (await alliance.connect(user).deposit(amount)).wait();
  }

  async function fundToTarget(ctx: any) {
    await approveAndDeposit(ctx.token, ctx.alliance, ctx.alice, ethers.parseEther("500"));
    await approveAndDeposit(ctx.token, ctx.alliance, ctx.bob, ethers.parseEther("300"));
    await approveAndDeposit(ctx.token, ctx.alliance, ctx.carol, ethers.parseEther("200"));
  }

  async function acquireNft(ctx: any, tokenId = 1) {
    await fundToTarget(ctx);
    await (await ctx.nft.connect(ctx.seller).approve(await ctx.alliance.getAddress(), tokenId)).wait();
    await (await ctx.alliance.connect(ctx.alice).buyNFT(await ctx.nft.getAddress(), tokenId, ctx.seller.address)).wait();
  }

  it("constructor/base state", async function () {
    const { alliance, admin, alice } = await deploy();
    expect(await alliance.owner()).to.eq(admin.address);
    expect(await alliance.targetPrice()).to.eq(TARGET);
    expect(await alliance.minSalePrice()).to.eq(TARGET);
    expect(await alliance.sharePercent(alice.address)).to.eq(50n);
  });

  it("deposit edge cases", async function () {
    const { alliance, outsider, alice, bob, token } = await deploy();

    await expect(alliance.connect(outsider).deposit(1)).to.be.revertedWith("Alliance: only participant");

    await (await token.connect(alice).approve(await alliance.getAddress(), 1n)).wait();
    await expect(alliance.connect(alice).deposit(0)).to.be.revertedWith("Alliance: zero amount");

    await approveAndDeposit(token, alliance, alice, ethers.parseEther("900"));
    await (await token.connect(bob).approve(await alliance.getAddress(), ethers.parseEther("200"))).wait();
    await expect(alliance.connect(bob).deposit(ethers.parseEther("200"))).to.be.revertedWith("Alliance: exceeds target");

    await networkHelpers.time.increase(8 * DAY);
    await expect(alliance.connect(alice).deposit(1)).to.be.revertedWith("Alliance: funding over");
  });

  it("cancel + refund flow", async function () {
    const { alliance, alice, bob, token } = await deploy();

    await approveAndDeposit(token, alliance, alice, ethers.parseEther("300"));
    await expect(alliance.connect(alice).cancelFunding()).to.be.revertedWith("Alliance: funding active");

    await networkHelpers.time.increase(8 * DAY);
    await (await alliance.connect(bob).cancelFunding()).wait();

    const before = await token.balanceOf(alice.address);
    await (await alliance.connect(alice).withdrawRefund()).wait();
    const after = await token.balanceOf(alice.address);
    expect(after - before).to.eq(ethers.parseEther("300"));

    await expect(alliance.connect(alice).withdrawRefund()).to.be.revertedWith("Alliance: nothing to refund");
  });

  it("buy/vote/execute full flow", async function () {
    const ctx = await deploy();
    await acquireNft(ctx, 1);

    const now = await networkHelpers.time.latest();
    const deadline = BigInt(now + 2 * DAY);
    const price = ethers.parseEther("1200");

    await (await ctx.alliance.connect(ctx.alice).voteToSell(ctx.buyer.address, price, deadline)).wait();
    await (await ctx.alliance.connect(ctx.bob).voteToSell(ctx.buyer.address, price, deadline)).wait();

    await (await ctx.token.connect(ctx.buyer).approve(await ctx.alliance.getAddress(), price)).wait();
    await (await ctx.alliance.connect(ctx.carol).executeSale()).wait();

    expect(await ctx.nft.ownerOf(1)).to.eq(ctx.buyer.address);
    expect(await ctx.alliance.state()).to.eq(2n);
  });

  it("vote mismatch checks", async function () {
    const ctx = await deploy();
    await acquireNft(ctx, 1);

    const now = await networkHelpers.time.latest();
    const deadline = BigInt(now + 2 * DAY);
    const price = ethers.parseEther("1200");

    await (await ctx.alliance.connect(ctx.alice).voteToSell(ctx.buyer.address, price, deadline)).wait();

    await expect(
      ctx.alliance.connect(ctx.bob).voteToSell(ctx.altBuyer.address, price, deadline)
    ).to.be.revertedWith("Alliance: buyer mismatch");

    await expect(
      ctx.alliance.connect(ctx.bob).voteToSell(ctx.buyer.address, ethers.parseEther("1300"), deadline)
    ).to.be.revertedWith("Alliance: price mismatch");
  });

  it("loss sale requires high quorum", async function () {
    const ctx = await deploy();
    await acquireNft(ctx, 1);

    const now = await networkHelpers.time.latest();
    const deadline = BigInt(now + 2 * DAY);
    const lossPrice = ethers.parseEther("900");

    await (await ctx.alliance.connect(ctx.alice).voteToSell(ctx.buyer.address, lossPrice, deadline)).wait();
    await (await ctx.alliance.connect(ctx.carol).voteToSell(ctx.buyer.address, lossPrice, deadline)).wait();

    await (await ctx.token.connect(ctx.buyer).approve(await ctx.alliance.getAddress(), lossPrice)).wait();
    await expect(ctx.alliance.connect(ctx.bob).executeSale()).to.be.revertedWith("Alliance: quorum not reached");
  });

  it("reset proposal after expiry", async function () {
    const ctx = await deploy();
    await acquireNft(ctx, 1);

    const now = await networkHelpers.time.latest();
    const deadline = BigInt(now + DAY);
    await (await ctx.alliance.connect(ctx.alice).voteToSell(ctx.buyer.address, ethers.parseEther("1100"), deadline)).wait();

    await expect(ctx.alliance.connect(ctx.bob).resetSaleProposal()).to.be.revertedWith("Alliance: proposal active");

    await networkHelpers.time.increase(2 * DAY);
    await (await ctx.alliance.connect(ctx.bob).resetSaleProposal()).wait();

    expect(await ctx.alliance.proposedPrice()).to.eq(0n);
  });

  it("emergency flow", async function () {
    const ctx = await deploy();
    await acquireNft(ctx, 1);

    await (await ctx.alliance.connect(ctx.alice).voteEmergencyWithdraw(ctx.carol.address)).wait();
    await (await ctx.alliance.connect(ctx.bob).voteEmergencyWithdraw(ctx.carol.address)).wait();

    await (await ctx.alliance.connect(ctx.alice).emergencyWithdrawNFT()).wait();
    expect(await ctx.nft.ownerOf(1)).to.eq(ctx.carol.address);
  });

  it("pause/unpause owner only", async function () {
    const { alliance, admin, outsider, alice, token } = await deploy();

    await expect(alliance.connect(outsider).pause())
      .to.be.revertedWithCustomError(alliance, "OwnableUnauthorizedAccount")
      .withArgs(outsider.address);

    await (await alliance.connect(admin).pause()).wait();
    await (await token.connect(alice).approve(await alliance.getAddress(), 1n)).wait();
    await expect(alliance.connect(alice).deposit(1n)).to.be.revertedWithCustomError(
      alliance,
      "EnforcedPause"
    );

    await (await alliance.connect(admin).unpause()).wait();
  });

  it("token owner controls", async function () {
    const { token, outsider, alice } = await deploy();

    await expect(token.connect(outsider).mint(outsider.address, 1))
      .to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount")
      .withArgs(outsider.address);
    await expect(token.connect(outsider).pause())
      .to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount")
      .withArgs(outsider.address);

    await (await token.pause()).wait();
    await expect(token.connect(outsider).transfer(alice.address, 1)).to.be.revertedWithCustomError(
      token,
      "EnforcedPause"
    );
    await (await token.unpause()).wait();
  });

  it("factory create + reverts + owner set", async function () {
    const { deployer, token, alice, bob, carol } = await deploy();

    const Factory = await ethers.getContractFactory("AllianceFactory", deployer);
    const factory = await Factory.deploy();
    await factory.waitForDeployment();

    await expect(
      factory.createAlliance(1, DAY, [alice.address, bob.address], [100], await token.getAddress())
    ).to.be.revertedWith("Factory: length mismatch");

    await expect(
      factory.createAlliance(1, DAY, [alice.address, bob.address], [70, 20], await token.getAddress())
    ).to.be.revertedWith("Factory: shares must sum to 100");

    await expect(
      factory.createAlliance(1, DAY, [alice.address, bob.address], [60, 40], ethers.ZeroAddress)
    ).to.be.revertedWith("Factory: zero token");

    await (await factory.connect(carol).createAlliance(
      ethers.parseEther("100"),
      DAY,
      [alice.address, bob.address],
      [60, 40],
      await token.getAddress()
    )).wait();

    const created = await factory.alliances(0);
    const createdAlliance = await ethers.getContractAt("Alliance", created);
    expect(await createdAlliance.owner()).to.eq(carol.address);
  });
});
