/**
 * @file PriceOracle.fully.ts
 * @notice PriceOracle TWAP update/consult and guard tests.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {addLiquidityViaRouter, deadlineFromNow, deployDexFixture} from "./helpers.js";

/** @notice describe: PriceOracle */
describe("PriceOracle", function () {
    /** @notice it: updates observation and returns TWAP consult quote */
    it("updates and consults twap for both token sides", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, user2, tokenA, tokenB, router, oracle} = fixture;

        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("1000"),
            ethers.parseEther("1000")
        );

        await oracle.update(poolAddress);
        await fixture.networkHelpers.time.increase(10);

        await tokenA.connect(user2).approve(await router.getAddress(), ethers.parseEther("10"));
        await router.connect(user2).swapExactTokensForTokens(
            ethers.parseEther("10"),
            0,
            [await tokenA.getAddress(), await tokenB.getAddress()],
            user2.address,
            await deadlineFromNow(fixture.networkHelpers)
        );

        await expect(oracle.update(poolAddress)).to.emit(oracle, "OracleUpdated");
        const outA = await oracle.consult(poolAddress, ethers.parseEther("1"), await tokenA.getAddress());
        const outB = await oracle.consult(poolAddress, ethers.parseEther("1"), await tokenB.getAddress());
        expect(outA).to.be.gt(0n);
        expect(outB).to.be.gt(0n);
    });

    /** @notice it: validates initialization and pause checks */
    it("reverts when not initialized, stale, or paused", async function () {
        const fixture = await deployDexFixture();
        const {ethers, oracle, tokenA, user1} = fixture;

        await expect(oracle.consult(await tokenA.getAddress(), 1n, await tokenA.getAddress()))
            .to.be.revertedWithCustomError(oracle, "NotInitialized");

        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            fixture.tokenA,
            fixture.tokenB,
            ethers.parseEther("100"),
            ethers.parseEther("100")
        );
        await oracle.update(poolAddress);

        await oracle.pause();
        await expect(oracle.update(poolAddress)).to.be.revertedWithCustomError(oracle, "EnforcedPause");
        await oracle.unpause();

        await expect(oracle.connect(user1).pause())
            .to.be.revertedWithCustomError(oracle, "OwnableUnauthorizedAccount")
            .withArgs(user1.address);
    });
});
