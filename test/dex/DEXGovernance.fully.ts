/**
 * @file DEXGovernance.fully.ts
 * @notice DEXGovernance timelock queue/execute/cancel and access tests.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {deployDexFixture} from "./helpers.js";

/** @notice describe: DEXGovernance */
describe("DEXGovernance", function () {
    /** @notice it: queues, executes, and cancels timelocked actions */
    it("handles governance queue/execute/cancel flow", async function () {
        const fixture = await deployDexFixture();
        const {ethers, governance, poolFactory, feeCollector, networkHelpers, flashLoanLimiter} = fixture;
        await poolFactory.transferOwnership(await governance.getAddress());

        await governance.queueSetFeeConfig(40, 5, await feeCollector.getAddress());
        await expect(governance.executeSetFeeConfig(40, 5, await feeCollector.getAddress()))
            .to.be.revertedWithCustomError(governance, "DelayNotMet");
        await networkHelpers.time.increase(3601);
        await expect(governance.executeSetFeeConfig(40, 5, await feeCollector.getAddress()))
            .to.emit(governance, "ActionExecuted");
        expect(await poolFactory.swapFeeBps()).to.equal(40n);

        await governance.queueSetEmergencyPause(true);
        await networkHelpers.time.increase(3601);
        await governance.executeSetEmergencyPause(true);
        expect(await poolFactory.paused()).to.equal(true);

        await governance.queueSetEmergencyPause(false);
        await networkHelpers.time.increase(3601);
        await governance.executeSetEmergencyPause(false);
        expect(await poolFactory.paused()).to.equal(false);

        await governance.queueSetFlashLoanLimiter(await flashLoanLimiter.getAddress());
        await networkHelpers.time.increase(3601);
        await governance.executeSetFlashLoanLimiter(await flashLoanLimiter.getAddress());

        const actionId = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(["string", "uint256", "uint256", "address"], ["setFeeConfig", 33, 1, await feeCollector.getAddress()])
        );
        await governance.queueSetFeeConfig(33, 1, await feeCollector.getAddress());
        await expect(governance.cancel(actionId)).to.emit(governance, "ActionCancelled").withArgs(actionId);
    });

    /** @notice it: validates duplicate queue, missing actions, pause and ownership */
    it("covers revert branches for governance controls", async function () {
        const fixture = await deployDexFixture();
        const {governance, feeCollector, user1} = fixture;

        await governance.queueSetFeeConfig(31, 1, await feeCollector.getAddress());
        await expect(governance.queueSetFeeConfig(31, 1, await feeCollector.getAddress()))
            .to.be.revertedWithCustomError(governance, "ActionAlreadyQueued");

        await expect(governance.executeSetFlashLoanLimiter(await feeCollector.getAddress()))
            .to.be.revertedWithCustomError(governance, "ActionNotQueued");
        await expect(governance.cancel("0x" + "00".repeat(32)))
            .to.be.revertedWithCustomError(governance, "ActionNotQueued");

        await governance.pause();
        await expect(governance.queueSetEmergencyPause(false))
            .to.be.revertedWithCustomError(governance, "EnforcedPause");
        await governance.unpause();

        await expect(governance.connect(user1).pause())
            .to.be.revertedWithCustomError(governance, "OwnableUnauthorizedAccount")
            .withArgs(user1.address);
    });
});

