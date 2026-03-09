/**
 * @file LiquidityMining.fully.ts
 * @notice LiquidityMining reward accrual and admin/guard coverage.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {addLiquidityViaRouter, deployDexFixture, deployUpgradeable} from "./helpers.js";

/** @notice describe: LiquidityMining */
describe("LiquidityMining", function () {
    /** @notice it: accrues and distributes rewards through deposit/claim/withdraw */
    it("accrues and pays staking rewards", async function () {
        const fixture = await deployDexFixture();
        const {ethers, admin, user1, tokenA, tokenB, rewardToken} = fixture;
        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("1000"),
            ethers.parseEther("1000")
        );

        const mining = await deployUpgradeable(
            ethers,
            admin,
            "LiquidityMining",
            [admin.address, poolAddress, await rewardToken.getAddress(), ethers.parseEther("1")]
        );
        await rewardToken.mint(await mining.getAddress(), ethers.parseEther("100000"));

        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);
        const stakeAmount = (await pool.balanceOf(user1.address)) / 2n;
        await pool.connect(user1).approve(await mining.getAddress(), stakeAmount);

        await expect(mining.connect(user1).deposit(stakeAmount)).to.emit(mining, "Deposited");
        await fixture.networkHelpers.time.increase(30);

        const pending = await mining.pendingRewards(user1.address);
        expect(pending).to.be.gt(0n);

        await expect(mining.connect(user1).claim()).to.emit(mining, "RewardClaimed");
        await expect(mining.connect(user1).withdraw(stakeAmount / 2n)).to.emit(mining, "Withdrawn");
        await expect(mining.connect(user1).withdraw(stakeAmount))
            .to.be.revertedWithCustomError(mining, "InsufficientStake");
    });

    /** @notice it: covers zero-amount, emission update, pause, and owner checks */
    it("covers admin and guard branches", async function () {
        const fixture = await deployDexFixture();
        const {ethers, admin, user1, tokenA, tokenB, rewardToken} = fixture;
        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("100"),
            ethers.parseEther("100")
        );

        const mining = await deployUpgradeable(
            ethers,
            admin,
            "LiquidityMining",
            [admin.address, poolAddress, await rewardToken.getAddress(), 1]
        );
        await rewardToken.mint(await mining.getAddress(), ethers.parseEther("1000"));

        await expect(mining.connect(user1).setRewardPerSecond(2))
            .to.be.revertedWithCustomError(mining, "OwnableUnauthorizedAccount")
            .withArgs(user1.address);

        await expect(mining.setRewardPerSecond(2)).to.emit(mining, "EmissionUpdated");
        await expect(mining.connect(user1).deposit(0)).to.be.revertedWithCustomError(mining, "ZeroAmount");
        await expect(mining.connect(user1).withdraw(0)).to.be.revertedWithCustomError(mining, "ZeroAmount");

        await mining.pause();
        await expect(mining.setRewardPerSecond(2)).to.be.revertedWithCustomError(mining, "EnforcedPause");
        await mining.unpause();
    });
});

