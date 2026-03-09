/**
 * @file FeeCollector.fully.ts
 * @notice FeeCollector treasury withdrawal and emergency-path coverage.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {deployDexFixture} from "./helpers.js";

/** @notice describe: FeeCollector */
describe("FeeCollector", function () {
    /** @notice it: withdraws, batch withdraws, and validates inputs */
    it("handles normal withdrawals and validation reverts", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB, feeCollector} = fixture;

        await tokenA.mint(await feeCollector.getAddress(), ethers.parseEther("100"));
        await tokenB.mint(await feeCollector.getAddress(), ethers.parseEther("100"));

        await expect(feeCollector.withdraw(await tokenA.getAddress(), user1.address, ethers.parseEther("10")))
            .to.emit(feeCollector, "FeeWithdrawn");

        await expect(
            feeCollector.batchWithdraw(
                [await tokenA.getAddress(), await tokenB.getAddress()],
                [user1.address, user1.address],
                [ethers.parseEther("5"), ethers.parseEther("5")]
            )
        ).to.emit(feeCollector, "FeeWithdrawn");

        await expect(
            feeCollector.withdraw(await tokenA.getAddress(), user1.address, ethers.parseEther("1000"))
        ).to.be.revertedWithCustomError(feeCollector, "InsufficientContractBalance");
        await expect(
            feeCollector.withdraw(await tokenA.getAddress(), ethers.ZeroAddress, 1n)
        ).to.be.revertedWithCustomError(feeCollector, "InvalidRecipient");
        await expect(
            feeCollector.withdraw(await tokenA.getAddress(), user1.address, 0)
        ).to.be.revertedWithCustomError(feeCollector, "ZeroAmount");
        await expect(
            feeCollector.batchWithdraw([await tokenA.getAddress()], [user1.address, user1.address], [1n])
        ).to.be.revertedWithCustomError(feeCollector, "LengthMismatch");

        await expect(
            feeCollector.batchWithdraw([await tokenA.getAddress()], [ethers.ZeroAddress], [1n])
        ).to.be.revertedWithCustomError(feeCollector, "InvalidRecipient");
        await expect(
            feeCollector.batchWithdraw([await tokenA.getAddress()], [user1.address], [0n])
        ).to.be.revertedWithCustomError(feeCollector, "ZeroAmount");
        await expect(
            feeCollector.batchWithdraw([await tokenA.getAddress()], [user1.address], [ethers.parseEther("9999")])
        ).to.be.revertedWithCustomError(feeCollector, "InsufficientContractBalance");
    });

    /** @notice it: enforces pause and emergency withdrawal paths */
    it("enforces pause semantics and owner-only actions", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, feeCollector} = fixture;

        await tokenA.mint(await feeCollector.getAddress(), ethers.parseEther("20"));
        await expect(feeCollector.connect(user1).pause())
            .to.be.revertedWithCustomError(feeCollector, "OwnableUnauthorizedAccount")
            .withArgs(user1.address);

        await feeCollector.pause();
        await expect(feeCollector.withdraw(await tokenA.getAddress(), user1.address, 1n))
            .to.be.revertedWithCustomError(feeCollector, "EnforcedPause");

        await expect(
            feeCollector.emergencyWithdraw(await tokenA.getAddress(), user1.address, ethers.parseEther("1"))
        ).to.emit(feeCollector, "FeeWithdrawn");
        await expect(
            feeCollector.emergencyWithdraw(await tokenA.getAddress(), user1.address, ethers.parseEther("1000"))
        ).to.be.revertedWithCustomError(feeCollector, "InsufficientContractBalance");
        await expect(
            feeCollector.emergencyWithdraw(await tokenA.getAddress(), ethers.ZeroAddress, 1n)
        ).to.be.revertedWithCustomError(feeCollector, "InvalidRecipient");
        await expect(
            feeCollector.emergencyWithdraw(await tokenA.getAddress(), user1.address, 0)
        ).to.be.revertedWithCustomError(feeCollector, "ZeroAmount");
        await feeCollector.unpause();
    });
});
