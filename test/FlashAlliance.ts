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
  const BASE_QUORUM = 60n;
  const LOSS_QUORUM = 80n;

  beforeEach(async function () {
    const connection = await hre.network.connect();
    ({ ethers, networkHelpers } = connection);
  });

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
      admin.address,
      BASE_QUORUM,
      LOSS_QUORUM,
      TARGET
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
    const now = await networkHelpers.time.latest();
    const acquisitionDeadline = BigInt(now + DAY);
    await (await ctx.nft.connect(ctx.seller).approve(await ctx.alliance.getAddress(), tokenId)).wait();
    await (await ctx.alliance.connect(ctx.alice).voteToAcquire(
      await ctx.nft.getAddress(),
      tokenId,
      ctx.seller.address,
      TARGET,
      acquisitionDeadline
    )).wait();
    await (await ctx.alliance.connect(ctx.bob).voteToAcquire(
      await ctx.nft.getAddress(),
      tokenId,
      ctx.seller.address,
      TARGET,
      acquisitionDeadline
    )).wait();
    await (await ctx.alliance.connect(ctx.alice).buyNFT()).wait();
  }

  it("constructor/base state", async function () {
    const { alliance, admin, alice, bob, carol } = await deploy();
    expect(await alliance.owner()).to.eq(admin.address);
    expect(await alliance.targetPrice()).to.eq(TARGET);
    expect(await alliance.minSalePrice()).to.eq(TARGET);
    expect(await alliance.quorumPercent()).to.eq(BASE_QUORUM);
    expect(await alliance.lossSaleQuorumPercent()).to.eq(LOSS_QUORUM);
    expect(await alliance.sharePercent(alice.address)).to.eq(50n);
    expect(await alliance.requiredContribution(alice.address)).to.eq(ethers.parseEther("500"));
    expect(await alliance.requiredContribution(bob.address)).to.eq(ethers.parseEther("300"));
    expect(await alliance.requiredContribution(carol.address)).to.eq(ethers.parseEther("200"));
  });

  it("deposit enforces per-participant quotas", async function () {
    const { alliance, outsider, alice, bob, token } = await deploy();

    await expect(alliance.connect(outsider).deposit(1)).to.be.revertedWith("Alliance: only participant");

    await (await token.connect(alice).approve(await alliance.getAddress(), 1n)).wait();
    await expect(alliance.connect(alice).deposit(0)).to.be.revertedWith("Alliance: zero amount");

    await approveAndDeposit(token, alliance, alice, ethers.parseEther("500"));
    await expect(alliance.connect(alice).deposit(1n)).to.be.revertedWith("Alliance: quota filled");

    await (await token.connect(bob).approve(await alliance.getAddress(), ethers.parseEther("301"))).wait();
    await expect(alliance.connect(bob).deposit(ethers.parseEther("301"))).to.be.revertedWith("Alliance: exceeds quota");

    await networkHelpers.time.increase(8 * DAY);
    await expect(alliance.connect(bob).deposit(1)).to.be.revertedWith("Alliance: funding over");
  });

  it("cancel + refund flow", async function () {
    const { alliance, alice, bob, token, admin } = await deploy();

    await approveAndDeposit(token, alliance, alice, ethers.parseEther("300"));
    await expect(alliance.connect(alice).cancelFunding()).to.be.revertedWith("Alliance: funding active");

    await networkHelpers.time.increase(8 * DAY);
    await (await alliance.connect(bob).cancelFunding()).wait();
    await (await alliance.connect(admin).pause()).wait();

    const before = await token.balanceOf(alice.address);
    await (await alliance.connect(alice).withdrawRefund()).wait();
    const after = await token.balanceOf(alice.address);
    expect(after - before).to.eq(ethers.parseEther("300"));

    await expect(alliance.connect(alice).withdrawRefund()).to.be.revertedWith("Alliance: nothing to refund");
  });

  it("acquisition requires quorum and immutable params", async function () {
    const ctx = await deploy();
    await fundToTarget(ctx);
    await (await ctx.nft.connect(ctx.seller).approve(await ctx.alliance.getAddress(), 1)).wait();

    const now = await networkHelpers.time.latest();
    const acquisitionDeadline = BigInt(now + DAY);

    await expect(ctx.alliance.connect(ctx.alice).buyNFT()).to.be.revertedWith("Alliance: no acquisition proposal");

    await (await ctx.alliance.connect(ctx.alice).voteToAcquire(
      await ctx.nft.getAddress(),
      1,
      ctx.seller.address,
      TARGET,
      acquisitionDeadline
    )).wait();
    await expect(ctx.alliance.connect(ctx.alice).buyNFT()).to.be.revertedWith("Alliance: quorum not reached");

    await expect(
      ctx.alliance.connect(ctx.bob).voteToAcquire(
        await ctx.nft.getAddress(),
        2,
        ctx.seller.address,
        TARGET,
        acquisitionDeadline
      )
    ).to.be.revertedWith("Alliance: token mismatch");

    await (await ctx.alliance.connect(ctx.bob).voteToAcquire(
      await ctx.nft.getAddress(),
      1,
      ctx.seller.address,
      TARGET,
      acquisitionDeadline
    )).wait();

    await (await ctx.alliance.connect(ctx.carol).buyNFT()).wait();
    expect(await ctx.nft.ownerOf(1)).to.eq(await ctx.alliance.getAddress());
    expect(await ctx.alliance.state()).to.eq(1n);
  });

  it("can reset expired acquisition proposal", async function () {
    const ctx = await deploy();
    await fundToTarget(ctx);
    await (await ctx.nft.connect(ctx.seller).approve(await ctx.alliance.getAddress(), 1)).wait();

    const now = await networkHelpers.time.latest();
    const acquisitionDeadline = BigInt(now + DAY);
    await (await ctx.alliance.connect(ctx.alice).voteToAcquire(
      await ctx.nft.getAddress(),
      1,
      ctx.seller.address,
      TARGET,
      acquisitionDeadline
    )).wait();

    await expect(ctx.alliance.connect(ctx.bob).resetAcquisitionProposal()).to.be.revertedWith("Alliance: acquisition active");
    await networkHelpers.time.increase(2 * DAY);
    await (await ctx.alliance.connect(ctx.bob).resetAcquisitionProposal()).wait();

    expect(await ctx.alliance.proposedAcquisitionPrice()).to.eq(0n);
    expect(await ctx.alliance.acquisitionVotesWeight()).to.eq(0n);
    expect(await ctx.alliance.acquisitionVoteRound()).to.eq(2n);
  });

  it("buy/vote/execute flow allocates claimable proceeds", async function () {
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
    expect(await ctx.alliance.saleProceedsAllocated()).to.eq(true);
    expect(await ctx.alliance.pendingProceeds(ctx.alice.address)).to.eq(ethers.parseEther("600"));
    expect(await ctx.alliance.pendingProceeds(ctx.bob.address)).to.eq(ethers.parseEther("360"));
    expect(await ctx.alliance.pendingProceeds(ctx.carol.address)).to.eq(ethers.parseEther("240"));

    const before = await ctx.token.balanceOf(ctx.alice.address);
    await (await ctx.alliance.connect(ctx.alice).claimProceeds()).wait();
    const after = await ctx.token.balanceOf(ctx.alice.address);
    expect(after - before).to.eq(ethers.parseEther("600"));
    await expect(ctx.alliance.connect(ctx.alice).claimProceeds()).to.be.revertedWith("Alliance: nothing to claim");
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
    expect(await ctx.alliance.saleVoteRound()).to.eq(2n);
  });

  it("emergency flow supports expiry and reset", async function () {
    const ctx = await deploy();
    await acquireNft(ctx, 1);

    const now = await networkHelpers.time.latest();
    const emergencyDeadline = BigInt(now + DAY);
    await (await ctx.alliance.connect(ctx.alice).voteEmergencyWithdraw(ctx.carol.address, emergencyDeadline)).wait();
    await (await ctx.alliance.connect(ctx.bob).voteEmergencyWithdraw(ctx.carol.address, emergencyDeadline)).wait();

    await (await ctx.alliance.connect(ctx.alice).emergencyWithdrawNFT()).wait();
    expect(await ctx.nft.ownerOf(1)).to.eq(ctx.carol.address);
  });

  it("can reset expired emergency proposal and revote", async function () {
    const ctx = await deploy();
    await acquireNft(ctx, 1);

    const now = await networkHelpers.time.latest();
    const emergencyDeadline = BigInt(now + DAY);
    await (await ctx.alliance.connect(ctx.alice).voteEmergencyWithdraw(ctx.carol.address, emergencyDeadline)).wait();

    await expect(ctx.alliance.connect(ctx.bob).resetEmergencyProposal()).to.be.revertedWith("Alliance: emergency active");

    await networkHelpers.time.increase(2 * DAY);
    await (await ctx.alliance.connect(ctx.bob).resetEmergencyProposal()).wait();

    expect(await ctx.alliance.emergencyVoteRound()).to.eq(2n);
    expect(await ctx.alliance.emergencyRecipient()).to.eq(ethers.ZeroAddress);

    const newEmergencyDeadline = BigInt((await networkHelpers.time.latest()) + DAY);
    await (await ctx.alliance.connect(ctx.alice).voteEmergencyWithdraw(ctx.bob.address, newEmergencyDeadline)).wait();
    expect(await ctx.alliance.hasVotedEmergency(ctx.alice.address)).to.eq(true);
  });

  it("summary getters expose current protocol state", async function () {
    const ctx = await deploy();
    await fundToTarget(ctx);

    const summary = await ctx.alliance.getAllianceSummary();
    expect(summary[0]).to.eq(0n);
    expect(summary[4]).to.eq(TARGET);
    expect(summary[5]).to.eq(TARGET);
    expect(summary[7]).to.eq(BASE_QUORUM);
    expect(summary[8]).to.eq(LOSS_QUORUM);

    const saleSummary = await ctx.alliance.getCurrentSaleProposal();
    expect(saleSummary[0]).to.eq(1n);
    expect(saleSummary[4]).to.eq(0n);
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

  it("factory create + reverts + owner set + indexes", async function () {
    const { deployer, token, alice, bob, carol } = await deploy();

    const Factory = await ethers.getContractFactory("AllianceFactory", deployer);
    const factory = await Factory.deploy();
    await factory.waitForDeployment();

    await expect(
      factory.createAlliance(1, DAY, [alice.address, bob.address], [100], await token.getAddress(), 60, 80, 1)
    ).to.be.revertedWith("Factory: length mismatch");

    await expect(
      factory.createAlliance(1, DAY, [alice.address, bob.address], [70, 20], await token.getAddress(), 60, 80, 1)
    ).to.be.revertedWith("Factory: shares must sum to 100");

    await expect(
      factory.createAlliance(1, DAY, [alice.address, bob.address], [60, 40], ethers.ZeroAddress, 60, 80, 1)
    ).to.be.revertedWith("Factory: zero token");

    await expect(
      factory.createAlliance(1, DAY, [alice.address, bob.address], [60, 40], await token.getAddress(), 0, 80, 1)
    ).to.be.revertedWith("Factory: bad quorum");

    await (await factory.connect(carol).createAlliance(
      ethers.parseEther("100"),
      DAY,
      [alice.address, bob.address],
      [60, 40],
      await token.getAddress(),
      65,
      90,
      ethers.parseEther("100")
    )).wait();

    const created = await factory.alliances(0);
    const createdAlliance = await ethers.getContractAt("Alliance", created);
    expect(await createdAlliance.owner()).to.eq(carol.address);
    expect(await createdAlliance.quorumPercent()).to.eq(65n);
    expect(await factory.isAlliance(created)).to.eq(true);
    expect(await factory.allAlliancesCount()).to.eq(1n);
    expect((await factory.getAlliancesByAdmin(carol.address))[0]).to.eq(created);
    expect((await factory.getAlliancesByParticipant(alice.address))[0]).to.eq(created);
  });
});
