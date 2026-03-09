/**
 * @file Mocks.fully.ts
 * @notice Coverage tests for mock helper contracts used in DEX test suite.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {deployDexFixture} from "./helpers.js";

/** @notice describe: Mock contracts */
describe("DEX mocks", function () {
    /** @notice it: covers MockWETH receive() wrapping path */
    it("wraps ETH through receive()", async function () {
        const {weth, user1} = await deployDexFixture();
        await user1.sendTransaction({to: await weth.getAddress(), value: 123n});
        expect(await weth.balanceOf(user1.address)).to.equal(123n);
    });

    /** @notice it: covers MockFlashSwapCallee skip-repay and tokenB repayment branches */
    it("covers flash callee branches", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB} = fixture;

        const callee = await ethers.deployContract("MockFlashSwapCallee", user1);
        await tokenA.mint(await callee.getAddress(), ethers.parseEther("10"));
        await tokenB.mint(await callee.getAddress(), ethers.parseEther("10"));

        await callee.configure(await tokenA.getAddress(), await tokenB.getAddress(), 1, 1, true);
        await callee.flashSwapCall(user1.address, 1, 1, "0x");

        await callee.configure(await tokenA.getAddress(), await tokenB.getAddress(), 0, 1, false);
        await callee.flashSwapCall(user1.address, 0, 1, "0x");
    });
});
