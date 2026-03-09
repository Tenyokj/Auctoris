/**
 * @file InitializationGuards.fully.ts
 * @notice Initialization guard and argument-validation coverage for upgradeable modules.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {deployDexFixture, deployUpgradeable, getConnection} from "./helpers.js";

/** @notice describe: Upgradeable initialization guards */
describe("Upgradeable initialization guards", function () {
    /** @notice it: validates zero-address guards across upgradeable contracts */
    it("reverts on invalid initialize arguments", async function () {
        const fixture = await deployDexFixture();
        const {ethers, admin, poolFactory, router, rewardToken, tokenA} = fixture;

        await expect(
            deployUpgradeable(ethers, admin, "PoolFactory", [ethers.ZeroAddress, await fixture.weth.getAddress()])
        ).to.be.revertedWithCustomError(poolFactory, "OwnableInvalidOwner");
        await expect(
            deployUpgradeable(ethers, admin, "PoolFactory", [admin.address, ethers.ZeroAddress])
        ).to.be.revertedWithCustomError(poolFactory, "InvalidWETH");

        await expect(
            deployUpgradeable(ethers, admin, "Router", [admin.address, ethers.ZeroAddress, await fixture.weth.getAddress()])
        ).to.be.revertedWithCustomError(router, "InvalidAddress");
        await expect(
            deployUpgradeable(ethers, admin, "RouterV2", [admin.address, await poolFactory.getAddress(), ethers.ZeroAddress])
        ).to.be.revertedWithCustomError(fixture.routerV2, "InvalidAddress");
        await expect(
            deployUpgradeable(ethers, admin, "PriceOracle", [ethers.ZeroAddress])
        ).to.be.revertedWithCustomError(fixture.oracle, "OwnableInvalidOwner");
        await expect(
            deployUpgradeable(ethers, admin, "FeeCollector", [ethers.ZeroAddress])
        ).to.be.revertedWithCustomError(fixture.feeCollector, "OwnableInvalidOwner");
        await expect(
            deployUpgradeable(ethers, admin, "DEXGovernance", [admin.address, await poolFactory.getAddress(), 0])
        ).to.be.revertedWithCustomError(fixture.governance, "InvalidDelay");
        await expect(
            deployUpgradeable(ethers, admin, "FlashLoanLimiter", [admin.address, 0])
        ).to.be.revertedWithCustomError(fixture.flashLoanLimiter, "InvalidBps");
        await expect(
            deployUpgradeable(ethers, admin, "LiquidityMining", [admin.address, ethers.ZeroAddress, await rewardToken.getAddress(), 1])
        ).to.be.revertedWithCustomError(fixture.router, "InvalidAddress");

        expect(await tokenA.name()).to.equal("Token A");
    });

    /** @notice it: prevents direct initialize on implementation contract */
    it("reverts initialize on implementation instances", async function () {
        const {ethers} = await getConnection();
        const [admin] = await ethers.getSigners();

        const impl = await ethers.deployContract("Router", admin);
        await expect(
            impl.initialize(admin.address, admin.address, admin.address)
        ).to.be.revertedWithCustomError(impl, "InvalidInitialization");
    });
});
