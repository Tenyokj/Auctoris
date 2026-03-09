/**
 * @file FlashLoanLimiter.fully.ts
 * @notice FlashLoanLimiter admin and validation-branch coverage.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {deployDexFixture} from "./helpers.js";

/** @notice describe: FlashLoanLimiter */
describe("FlashLoanLimiter", function () {
    /** @notice it: validates limits and owner controls */
    it("validates both token limits and pause flow", async function () {
        const fixture = await deployDexFixture();
        const {flashLoanLimiter, user1} = fixture;

        await expect(flashLoanLimiter.setDefaultLimit(2000)).to.emit(flashLoanLimiter, "DefaultLimitUpdated");
        await expect(flashLoanLimiter.setPoolLimit(user1.address, 1500)).to.emit(flashLoanLimiter, "PoolLimitUpdated");

        await flashLoanLimiter.validateFlashSwap(user1.address, user1.address, 1000, 1000, 100, 100);
        await expect(
            flashLoanLimiter.validateFlashSwap(user1.address, user1.address, 1000, 1000, 300, 0)
        ).to.be.revertedWithCustomError(flashLoanLimiter, "LimitExceeded");
        await expect(
            flashLoanLimiter.validateFlashSwap(user1.address, user1.address, 1000, 1000, 0, 300)
        ).to.be.revertedWithCustomError(flashLoanLimiter, "LimitExceeded");

        await flashLoanLimiter.pause();
        await expect(
            flashLoanLimiter.validateFlashSwap(user1.address, user1.address, 1000, 1000, 1, 1)
        ).to.be.revertedWithCustomError(flashLoanLimiter, "EnforcedPause");
        await flashLoanLimiter.unpause();
    });

    /** @notice it: validates bps bounds and ownership checks */
    it("validates bps and owner checks", async function () {
        const fixture = await deployDexFixture();
        const {user1, flashLoanLimiter} = fixture;

        await expect(flashLoanLimiter.setDefaultLimit(0)).to.be.revertedWithCustomError(flashLoanLimiter, "InvalidBps");
        await expect(flashLoanLimiter.setPoolLimit(user1.address, 10_000))
            .to.be.revertedWithCustomError(flashLoanLimiter, "InvalidBps");
        await expect(flashLoanLimiter.connect(user1).setDefaultLimit(1000))
            .to.be.revertedWithCustomError(flashLoanLimiter, "OwnableUnauthorizedAccount")
            .withArgs(user1.address);
    });
});

