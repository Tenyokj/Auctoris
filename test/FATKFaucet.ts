// test/FATKFaucet.ts
/**
 * @file FATKFaucet.ts
 * @notice Faucet claims, cooldown, owner controls, and withdrawals.
 */
import { hre, expect, type HardhatEthers, type NetworkHelpers } from "./setup.js";

describe("FATKFaucet", function () {
  let ethers: HardhatEthers;
  let networkHelpers: NetworkHelpers;

  beforeEach(async function () {
    const connection = await hre.network.connect();
    ({ ethers, networkHelpers } = connection);
  });

  async function deploy() {
    const [deployer, owner, user, other] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("FATK", deployer);
    const token = await Token.deploy(owner.address);
    await token.waitForDeployment();

    const claimAmount = ethers.parseUnits("10000", 18);
    const cooldown = 24 * 60 * 60;

    const Faucet = await ethers.getContractFactory("FATKFaucet", deployer);
    const faucet = await Faucet.deploy(
      await token.getAddress(),
      owner.address,
      claimAmount,
      cooldown
    );
    await faucet.waitForDeployment();

    return { deployer, owner, user, other, token, faucet, claimAmount, cooldown };
  }

  it("validates constructor params", async function () {
    const [deployer, owner] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("TenyokjToken", deployer);
    const token = await Token.deploy(owner.address);
    await token.waitForDeployment();

    const Faucet = await ethers.getContractFactory("FATKFaucet", deployer);

    await expect(
      Faucet.deploy(ethers.ZeroAddress, owner.address, 1n, 1n)
    ).to.be.revertedWith("Faucet: zero token");

    await expect(
      Faucet.deploy(await token.getAddress(), ethers.ZeroAddress, 1n, 1n)
    ).to.be.revertedWith("Faucet: zero owner");

    await expect(
      Faucet.deploy(await token.getAddress(), owner.address, 0n, 1n)
    ).to.be.revertedWith("Faucet: zero amount");

    await expect(
      Faucet.deploy(await token.getAddress(), owner.address, 1n, 0n)
    ).to.be.revertedWith("Faucet: zero cooldown");
  });

  it("claims once, blocks during cooldown, allows after cooldown", async function () {
    const { owner, user, token, faucet, claimAmount, cooldown } = await deploy();

    // Fund faucet liquidity from token owner
    await (await token.connect(owner).mint(await faucet.getAddress(), ethers.parseUnits("1000000", 18))).wait();

    await expect(faucet.connect(user).claim()).to.emit(faucet, "Claimed");

    expect(await token.balanceOf(user.address)).to.equal(claimAmount);

    await expect(faucet.connect(user).claim()).to.be.revertedWith("Faucet: cooldown active");

    await networkHelpers.time.increase(cooldown + 1);

    await (await faucet.connect(user).claim()).wait();
    expect(await token.balanceOf(user.address)).to.equal(claimAmount * 2n);
  });

  it("owner controls: setClaimAmount/setClaimCooldown + non-owner blocked", async function () {
    const { owner, user, faucet } = await deploy();

    await expect(faucet.connect(user).setClaimAmount(1n))
      .to.be.revertedWithCustomError(faucet, "OwnableUnauthorizedAccount")
      .withArgs(user.address);

    await expect(faucet.connect(user).setClaimCooldown(1n))
      .to.be.revertedWithCustomError(faucet, "OwnableUnauthorizedAccount")
      .withArgs(user.address);

    await expect(faucet.connect(owner).setClaimAmount(0n)).to.be.revertedWith("Faucet: zero amount");
    await expect(faucet.connect(owner).setClaimCooldown(0n)).to.be.revertedWith("Faucet: zero cooldown");

    const newAmount = ethers.parseUnits("5000", 18);
    await (await faucet.connect(owner).setClaimAmount(newAmount)).wait();
    expect(await faucet.claimAmount()).to.equal(newAmount);

    await (await faucet.connect(owner).setClaimCooldown(3600n)).wait();
    expect(await faucet.claimCooldown()).to.equal(3600n);
  });

  it("owner can withdraw, non-owner blocked, zero recipient blocked", async function () {
    const { owner, user, other, token, faucet } = await deploy();

    await (await token.connect(owner).mint(await faucet.getAddress(), ethers.parseUnits("50000", 18))).wait();

    await expect(faucet.connect(user).withdraw(other.address, 1n))
      .to.be.revertedWithCustomError(faucet, "OwnableUnauthorizedAccount")
      .withArgs(user.address);

    await expect(faucet.connect(owner).withdraw(ethers.ZeroAddress, 1n))
      .to.be.revertedWith("Faucet: zero recipient");

    const amount = ethers.parseUnits("12345", 18);
    const before = await token.balanceOf(other.address);
    await (await faucet.connect(owner).withdraw(other.address, amount)).wait();
    const after = await token.balanceOf(other.address);

    expect(after - before).to.equal(amount);
  });

  it("updates lastClaimAt per wallet", async function () {
    const { owner, user, faucet, token } = await deploy();

    await (await token.connect(owner).mint(await faucet.getAddress(), ethers.parseUnits("100000", 18))).wait();

    const before = await faucet.lastClaimAt(user.address);
    expect(before).to.equal(0n);

    await (await faucet.connect(user).claim()).wait();

    const after = await faucet.lastClaimAt(user.address);
    expect(after).to.be.gt(0n);
  });
});
