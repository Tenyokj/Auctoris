/**
 * @file PoolFactory.fully.ts
 * @notice PoolFactory creation flow, admin controls, and edge-case coverage.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {deployDexFixture} from "./helpers.js";

/** @notice describe: PoolFactory full coverage */
describe("PoolFactory", function () {
    /** @notice it: creates a pool, stores mappings for both token orders, and emits event */
    it("creates a pool and indexes pair in both directions", async function () {
        const {poolFactory, tokenA, tokenB} = await deployDexFixture();

        await expect(poolFactory.createPool(await tokenA.getAddress(), await tokenB.getAddress()))
            .to.emit(poolFactory, "PoolCreated");

        const poolAB = await poolFactory.getPool(await tokenA.getAddress(), await tokenB.getAddress());
        const poolBA = await poolFactory.getPool(await tokenB.getAddress(), await tokenA.getAddress());
        expect(poolAB).to.equal(poolBA);
        expect(await poolFactory.allPoolsLength()).to.equal(1n);
    });

    /** @notice it: rejects invalid pair creation inputs and duplicate pools */
    it("rejects zero, identical, and duplicate pool creation", async function () {
        const {ethers, poolFactory, tokenA, tokenB} = await deployDexFixture();

        await expect(poolFactory.createPool(await tokenA.getAddress(), await tokenA.getAddress()))
            .to.be.revertedWithCustomError(poolFactory, "IdenticalTokenAddresses");

        await expect(poolFactory.createPool(ethers.ZeroAddress, await tokenB.getAddress()))
            .to.be.revertedWithCustomError(poolFactory, "ZeroAddressToken");

        await poolFactory.createPool(await tokenA.getAddress(), await tokenB.getAddress());
        await expect(poolFactory.createPool(await tokenB.getAddress(), await tokenA.getAddress()))
            .to.be.revertedWithCustomError(poolFactory, "PoolAlreadyExists");
    });

    /** @notice it: updates fee configuration and validates bounds */
    it("updates fee config and validates invalid values", async function () {
        const {poolFactory, feeCollector, ethers} = await deployDexFixture();

        await expect(poolFactory.setFeeConfig(45, 10, await feeCollector.getAddress()))
            .to.emit(poolFactory, "FeeConfigUpdated")
            .withArgs(45n, 10n, await feeCollector.getAddress());

        expect(await poolFactory.swapFeeBps()).to.equal(45n);
        expect(await poolFactory.protocolFeeBps()).to.equal(10n);

        await expect(poolFactory.setFeeConfig(10_000, 10, await feeCollector.getAddress()))
            .to.be.revertedWithCustomError(poolFactory, "InvalidFeeConfig");
        await expect(poolFactory.setFeeConfig(30, 31, await feeCollector.getAddress()))
            .to.be.revertedWithCustomError(poolFactory, "InvalidFeeConfig");
        await expect(poolFactory.setFeeConfig(30, 1, ethers.ZeroAddress))
            .to.be.revertedWithCustomError(poolFactory, "InvalidFeeConfig");
    });

    /** @notice it: updates flash loan limiter and validates non-zero address */
    it("updates flash loan limiter", async function () {
        const {ethers, poolFactory, flashLoanLimiter} = await deployDexFixture();

        await expect(poolFactory.setFlashLoanLimiter(await flashLoanLimiter.getAddress()))
            .to.emit(poolFactory, "FlashLoanLimiterUpdated")
            .withArgs(await flashLoanLimiter.getAddress());

        await expect(poolFactory.setFlashLoanLimiter(ethers.ZeroAddress))
            .to.be.revertedWithCustomError(poolFactory, "InvalidLimiter");
    });

    /** @notice it: enforces owner-only admin methods and pause behavior */
    it("enforces owner-only controls and pause state", async function () {
        const {user1, poolFactory, tokenA, tokenB} = await deployDexFixture();

        await expect(poolFactory.connect(user1).pause())
            .to.be.revertedWithCustomError(poolFactory, "OwnableUnauthorizedAccount")
            .withArgs(user1.address);
        await expect(poolFactory.connect(user1).setFeeConfig(30, 0, user1.address))
            .to.be.revertedWithCustomError(poolFactory, "OwnableUnauthorizedAccount")
            .withArgs(user1.address);

        await poolFactory.pause();
        await expect(poolFactory.createPool(await tokenA.getAddress(), await tokenB.getAddress()))
            .to.be.revertedWithCustomError(poolFactory, "EnforcedPause");

        await poolFactory.unpause();
        await expect(poolFactory.createPool(await tokenA.getAddress(), await tokenB.getAddress()))
            .to.emit(poolFactory, "PoolCreated");
    });
});

