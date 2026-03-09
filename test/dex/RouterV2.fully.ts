/**
 * @file RouterV2.fully.ts
 * @notice RouterV2 path optimization and execution tests.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {addLiquidityViaRouter, deadlineFromNow, deployDexFixture} from "./helpers.js";

/** @notice describe: RouterV2 */
describe("RouterV2", function () {
    /** @notice it: finds better 2-hop path and executes best-path swap */
    it("finds and executes best route", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, user2, tokenA, tokenB, tokenC, routerV2} = fixture;
        const deadline = await deadlineFromNow(fixture.networkHelpers);

        await addLiquidityViaRouter(fixture, user1, tokenA, tokenC, ethers.parseEther("100"), ethers.parseEther("100"));
        await addLiquidityViaRouter(fixture, user1, tokenA, tokenB, ethers.parseEther("2000"), ethers.parseEther("2000"));
        await addLiquidityViaRouter(fixture, user1, tokenB, tokenC, ethers.parseEther("2000"), ethers.parseEther("2000"));

        const quote = await routerV2.getBestPathOut(
            ethers.parseEther("10"),
            await tokenA.getAddress(),
            await tokenC.getAddress(),
            [await tokenB.getAddress()]
        );
        expect(quote[0].length).to.equal(3);

        await tokenA.connect(user2).approve(await routerV2.getAddress(), ethers.parseEther("10"));
        await expect(
            routerV2.connect(user2).swapBestTokensForTokens(
                ethers.parseEther("10"),
                0,
                await tokenA.getAddress(),
                await tokenC.getAddress(),
                [await tokenB.getAddress()],
                user2.address,
                deadline
            )
        ).to.emit(routerV2, "BestPathSwap");
    });

    /** @notice it: covers invalid inputs, candidate skips, and pause controls */
    it("covers invalid path and pause flows", async function () {
        const fixture = await deployDexFixture();
        const {user1, user2, tokenA, tokenB, tokenC, routerV2, poolFactory, ethers} = fixture;
        const deadline = await deadlineFromNow(fixture.networkHelpers);

        await expect(
            routerV2.getBestPathOut(1n, ethers.ZeroAddress, await tokenC.getAddress(), [])
        ).to.be.revertedWithCustomError(routerV2, "InvalidPath");

        const result = await routerV2.getBestPathOut(1n, await tokenA.getAddress(), await tokenC.getAddress(), [
            ethers.ZeroAddress,
            await tokenA.getAddress(),
            await tokenC.getAddress()
        ]);
        expect(result[0].length).to.equal(0);

        await poolFactory.createPool(await tokenA.getAddress(), await tokenB.getAddress()); // zero reserves
        const zeroReservePath = await routerV2.getBestPathOut(1n, await tokenA.getAddress(), await tokenC.getAddress(), [
            await tokenB.getAddress()
        ]);
        expect(zeroReservePath[0].length).to.equal(0);

        await tokenA.connect(user2).approve(await routerV2.getAddress(), 1n);
        await expect(
            routerV2.connect(user2).swapBestTokensForTokens(
                1n,
                0,
                await tokenA.getAddress(),
                await tokenC.getAddress(),
                [],
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(routerV2, "NoRoute");

        await poolFactory.pause();
        await expect(
            routerV2.connect(user2).swapBestTokensForTokens(
                1n,
                0,
                await tokenA.getAddress(),
                await tokenC.getAddress(),
                [],
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(routerV2, "ProtocolPaused");

        await expect(routerV2.connect(user1).pause())
            .to.be.revertedWithCustomError(routerV2, "OwnableUnauthorizedAccount")
            .withArgs(user1.address);

        await routerV2.pause();
        await expect(
            routerV2.connect(user2).swapBestTokensForTokens(
                1n,
                0,
                await tokenA.getAddress(),
                await tokenC.getAddress(),
                [],
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(routerV2, "EnforcedPause");
        await routerV2.unpause();
    });
});
