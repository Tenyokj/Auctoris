/**
 * @file TenjiAidrop.ts
 * @notice Coverage-oriented tests for TenjiAirdrop V3.
 */

import { expect } from "./setup.js";
import { getConnection } from "./helpers.js";

type DeployOptions = {
    amountPerUser?: bigint;
    maxUsers?: number;
    fundingAmount?: bigint;
};

async function deployAirdropFixture(options: DeployOptions = {}) {
    const { ethers, networkHelpers } = await getConnection();
    const [owner, user1, user2, user3, user4] = await ethers.getSigners();

    const amountPerUser = options.amountPerUser ?? ethers.parseEther("100");
    const maxUsers = options.maxUsers ?? 2;
    const fundingAmount =
        options.fundingAmount ?? amountPerUser * BigInt(maxUsers + 3);

    const token = await ethers.deployContract(
        "MockERC20",
        ["TenjiCoin", "TENJI"],
        owner
    );

    const airdrop = await ethers.deployContract(
        "TenjiAirdrop",
        [
            await token.getAddress(),
            amountPerUser,
            maxUsers,
            owner.address,
        ],
        owner
    );

    const caller = await ethers.deployContract(
        "AirdropClaimCaller",
        [],
        owner
    );

    if (fundingAmount > 0n) {
        await token.mint(await airdrop.getAddress(), fundingAmount);
    }

    return {
        ethers,
        networkHelpers,
        token,
        airdrop,
        caller,
        owner,
        user1,
        user2,
        user3,
        user4,
        amountPerUser,
        maxUsers,
        fundingAmount,
    };
}

function getMappingSlot(
    ethers: Awaited<ReturnType<typeof getConnection>>["ethers"],
    account: string,
    slot: bigint
) {
    return BigInt(
        ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
                ["address", "uint256"],
                [account, slot]
            )
        )
    );
}

async function setLastClaimBlock(
    ethers: Awaited<ReturnType<typeof getConnection>>["ethers"],
    networkHelpers: Awaited<ReturnType<typeof getConnection>>["networkHelpers"],
    airdropAddress: string,
    userAddress: string,
    blockNumber: bigint
) {
    const storageSlot = getMappingSlot(ethers, userAddress, 3n);

    await networkHelpers.setStorageAt(
        airdropAddress,
        storageSlot,
        blockNumber
    );
}

describe("TenjiAirdrop V3", function () {
    describe("constructor", function () {
        it("stores immutable config and sane defaults", async function () {
            const { airdrop, token, owner, amountPerUser } =
                await deployAirdropFixture();

            expect(await airdrop.token()).to.equal(await token.getAddress());
            expect(await airdrop.amountPerUser()).to.equal(amountPerUser);
            expect(await airdrop.maxUsers()).to.equal(2);
            expect(await airdrop.owner()).to.equal(owner.address);
            expect(await airdrop.cooldownBlocks()).to.equal(3);
        });

        it("rejects zero token address", async function () {
            const { ethers } = await getConnection();
            const [owner] = await ethers.getSigners();

            await expect(
                ethers.deployContract(
                    "TenjiAirdrop",
                    [ethers.ZeroAddress, 1, 1, owner.address],
                    owner
                )
            ).to.be.revertedWith("ZERO_TOKEN");
        });

        it("rejects zero owner", async function () {
            const { ethers } = await getConnection();
            const [owner] = await ethers.getSigners();
            const airdropFactory = await ethers.getContractFactory(
                "TenjiAirdrop",
                owner
            );

            const token = await ethers.deployContract(
                "MockERC20",
                ["TenjiCoin", "TENJI"],
                owner
            );

            await expect(
                ethers.deployContract(
                    "TenjiAirdrop",
                    [await token.getAddress(), 1, 1, ethers.ZeroAddress],
                    owner
                )
            ).to.be.revertedWithCustomError(
                airdropFactory,
                "OwnableInvalidOwner"
            ).withArgs(ethers.ZeroAddress);
        });

        it("rejects zero amount per user", async function () {
            const { ethers } = await getConnection();
            const [owner] = await ethers.getSigners();

            const token = await ethers.deployContract(
                "MockERC20",
                ["TenjiCoin", "TENJI"],
                owner
            );

            await expect(
                ethers.deployContract(
                    "TenjiAirdrop",
                    [await token.getAddress(), 0, 1, owner.address],
                    owner
                )
            ).to.be.revertedWith("INVALID_AMOUNT");
        });

        it("rejects zero max users", async function () {
            const { ethers } = await getConnection();
            const [owner] = await ethers.getSigners();

            const token = await ethers.deployContract(
                "MockERC20",
                ["TenjiCoin", "TENJI"],
                owner
            );

            await expect(
                ethers.deployContract(
                    "TenjiAirdrop",
                    [await token.getAddress(), 1, 0, owner.address],
                    owner
                )
            ).to.be.revertedWith("INVALID_MAX");
        });
    });

    describe("claim", function () {
        it("allows a valid claim and updates balances", async function () {
            const {
                airdrop,
                token,
                user1,
                amountPerUser,
                fundingAmount,
            } = await deployAirdropFixture();

            await expect(airdrop.connect(user1).claim())
                .to.emit(airdrop, "Claimed")
                .withArgs(user1.address, amountPerUser);

            expect(await token.balanceOf(user1.address)).to.equal(
                amountPerUser
            );
            expect(await airdrop.claimedCount()).to.equal(1);
            expect(await airdrop.hasClaimed(user1.address)).to.equal(true);
            expect(await airdrop.lastClaimBlock(user1.address)).to.be.gt(0);
            expect(await airdrop.remainingTokens()).to.equal(
                fundingAmount - amountPerUser
            );
        });

        it("prevents double claim with AlreadyClaimed", async function () {
            const { airdrop, user1 } = await deployAirdropFixture();

            await airdrop.connect(user1).claim();

            await expect(
                airdrop.connect(user1).claim()
            ).to.be.revertedWithCustomError(airdrop, "AlreadyClaimed");
        });

        it("enforces max users limit", async function () {
            const { airdrop, user1, user2, user3 } =
                await deployAirdropFixture();

            await airdrop.connect(user1).claim();
            await airdrop.connect(user2).claim();

            await expect(
                airdrop.connect(user3).claim()
            ).to.be.revertedWithCustomError(airdrop, "AirdropFinished");
        });

        it("rejects claims when token balance is below amountPerUser", async function () {
            const { airdrop, user1 } = await deployAirdropFixture({
                fundingAmount: 0n,
            });

            await expect(
                airdrop.connect(user1).claim()
            ).to.be.revertedWithCustomError(airdrop, "NoTokensLeft");
        });

        it("rejects contract-based calls", async function () {
            const { airdrop, caller, user1 } = await deployAirdropFixture();

            await expect(
                caller
                    .connect(user1)
                    .claimFromContract(await airdrop.getAddress())
            ).to.be.revertedWithCustomError(airdrop, "NotEOA");
        });

        it("rejects users that are still inside cooldown window", async function () {
            const { airdrop, user1, ethers, networkHelpers } =
                await deployAirdropFixture();

            const currentBlock = BigInt(await networkHelpers.time.latestBlock());

            await setLastClaimBlock(
                ethers,
                networkHelpers,
                await airdrop.getAddress(),
                user1.address,
                currentBlock
            );

            await expect(
                airdrop.connect(user1).claim()
            ).to.be.revertedWithCustomError(airdrop, "CooldownActive");
        });
    });

    describe("views and admin", function () {
        it("canClaim returns correct state before and after claim", async function () {
            const { airdrop, user1 } = await deployAirdropFixture();

            expect(await airdrop.canClaim(user1.address)).to.equal(true);

            await airdrop.connect(user1).claim();

            expect(await airdrop.canClaim(user1.address)).to.equal(false);
        });

        it("canClaim returns false when balance is insufficient", async function () {
            const { airdrop, user1 } = await deployAirdropFixture({
                fundingAmount: 0n,
            });

            expect(await airdrop.canClaim(user1.address)).to.equal(false);
        });

        it("canClaim returns false after max users are exhausted", async function () {
            const { airdrop, user1, user2, user3 } =
                await deployAirdropFixture();

            await airdrop.connect(user1).claim();
            await airdrop.connect(user2).claim();

            expect(await airdrop.canClaim(user3.address)).to.equal(false);
        });

        it("canClaim returns false for contract callers", async function () {
            const { airdrop, caller } = await deployAirdropFixture();

            expect(await airdrop.canClaim(await caller.getAddress())).to.equal(
                false
            );
        });

        it("canClaim respects cooldown marker and becomes true after enough blocks", async function () {
            const { airdrop, user1, ethers, networkHelpers } =
                await deployAirdropFixture();

            const airdropAddress = await airdrop.getAddress();
            const currentBlock = BigInt(await networkHelpers.time.latestBlock());

            await setLastClaimBlock(
                ethers,
                networkHelpers,
                airdropAddress,
                user1.address,
                currentBlock
            );

            expect(await airdrop.canClaim(user1.address)).to.equal(false);

            await networkHelpers.mine((await airdrop.cooldownBlocks()) + 1n);

            expect(await airdrop.canClaim(user1.address)).to.equal(true);
        });

        it("owner can update cooldown", async function () {
            const { airdrop } = await deployAirdropFixture();

            await airdrop.setCooldown(7);

            expect(await airdrop.cooldownBlocks()).to.equal(7);
        });

        it("non-owner cannot update cooldown", async function () {
            const { airdrop, user1 } = await deployAirdropFixture();

            await expect(
                airdrop.connect(user1).setCooldown(7)
            ).to.be.revertedWithCustomError(
                airdrop,
                "OwnableUnauthorizedAccount"
            ).withArgs(user1.address);
        });

    });
});
