/**
 * @file TenjiCoin.ts
 * @notice Tests for tax-free TenjiCoin distribution and transfers.
 */

import { expect } from "./setup.js";
import { getConnection } from "./helpers.js";

async function deployTokenFixture() {
    const { ethers } = await getConnection();
    const [liquidityWallet, teamWallet, airdropWallet, reserveWallet, user1, user2] =
        await ethers.getSigners();

    const token = await ethers.deployContract(
        "TenjiCoin",
        [
            liquidityWallet.address,
            teamWallet.address,
            airdropWallet.address,
            reserveWallet.address,
        ],
        liquidityWallet
    );

    return {
        ethers,
        token,
        liquidityWallet,
        teamWallet,
        airdropWallet,
        reserveWallet,
        user1,
        user2,
    };
}

describe("TenjiCoin", function () {
    it("stores token metadata and mints the full supply", async function () {
        const { ethers, token } = await deployTokenFixture();

        expect(await token.name()).to.equal("TenjiCoin");
        expect(await token.symbol()).to.equal("TENJI");
        expect(await token.decimals()).to.equal(18);
        expect(await token.totalSupply()).to.equal(
            ethers.parseEther("167000000000")
        );
    });

    it("mints the configured fixed launch distribution", async function () {
        const {
            ethers,
            token,
            liquidityWallet,
            teamWallet,
            airdropWallet,
            reserveWallet,
        } = await deployTokenFixture();

        expect(await token.balanceOf(liquidityWallet.address)).to.equal(
            ethers.parseEther("60000000000")
        );
        expect(await token.balanceOf(teamWallet.address)).to.equal(
            ethers.parseEther("20000000000")
        );
        expect(await token.balanceOf(airdropWallet.address)).to.equal(
            ethers.parseEther("20000000000")
        );
        expect(await token.balanceOf(reserveWallet.address)).to.equal(
            ethers.parseEther("67000000000")
        );
    });

    it("transfers tokens without any fee deduction", async function () {
        const { ethers, token, liquidityWallet, user1, user2 } =
            await deployTokenFixture();

        const initialOwnerBalance = await token.balanceOf(
            liquidityWallet.address
        );
        const firstTransfer = ethers.parseEther("1000");
        const secondTransfer = ethers.parseEther("250");

        await token.connect(liquidityWallet).transfer(user1.address, firstTransfer);
        await token.connect(user1).transfer(user2.address, secondTransfer);

        expect(await token.balanceOf(user1.address)).to.equal(
            firstTransfer - secondTransfer
        );
        expect(await token.balanceOf(user2.address)).to.equal(secondTransfer);
        expect(await token.balanceOf(liquidityWallet.address)).to.equal(
            initialOwnerBalance - firstTransfer
        );
    });

    it("burn reduces holder balance and total supply exactly", async function () {
        const { ethers, token, liquidityWallet } = await deployTokenFixture();

        const burnAmount = ethers.parseEther("1000");
        const initialSupply = await token.totalSupply();
        const initialBalance = await token.balanceOf(liquidityWallet.address);

        await token.connect(liquidityWallet).burn(burnAmount);

        expect(await token.totalSupply()).to.equal(initialSupply - burnAmount);
        expect(await token.balanceOf(liquidityWallet.address)).to.equal(
            initialBalance - burnAmount
        );
    });

    it("rejects zero liquidity wallet", async function () {
        const { ethers } = await getConnection();
        const [, teamWallet, airdropWallet, reserveWallet, deployer] = await ethers.getSigners();

        await expect(
            ethers.deployContract(
                "TenjiCoin",
                [
                    ethers.ZeroAddress,
                    teamWallet.address,
                    airdropWallet.address,
                    reserveWallet.address,
                ],
                deployer
            )
        ).to.be.revertedWithCustomError(
            { interface: (await ethers.getContractFactory("TenjiCoin", deployer)).interface },
            "ZeroAddress"
        );
    });

    it("rejects zero team wallet", async function () {
        const { ethers } = await getConnection();
        const [liquidityWallet, , airdropWallet, reserveWallet] = await ethers.getSigners();

        await expect(
            ethers.deployContract(
                "TenjiCoin",
                [
                    liquidityWallet.address,
                    ethers.ZeroAddress,
                    airdropWallet.address,
                    reserveWallet.address,
                ],
                liquidityWallet
            )
        ).to.be.revertedWithCustomError(
            { interface: (await ethers.getContractFactory("TenjiCoin", liquidityWallet)).interface },
            "ZeroAddress"
        );
    });

    it("rejects zero airdrop wallet", async function () {
        const { ethers } = await getConnection();
        const [liquidityWallet, teamWallet, , reserveWallet] = await ethers.getSigners();

        await expect(
            ethers.deployContract(
                "TenjiCoin",
                [
                    liquidityWallet.address,
                    teamWallet.address,
                    ethers.ZeroAddress,
                    reserveWallet.address,
                ],
                liquidityWallet
            )
        ).to.be.revertedWithCustomError(
            { interface: (await ethers.getContractFactory("TenjiCoin", liquidityWallet)).interface },
            "ZeroAddress"
        );
    });

    it("rejects zero reserve wallet", async function () {
        const { ethers } = await getConnection();
        const [liquidityWallet, teamWallet, airdropWallet] = await ethers.getSigners();

        await expect(
            ethers.deployContract(
                "TenjiCoin",
                [
                    liquidityWallet.address,
                    teamWallet.address,
                    airdropWallet.address,
                    ethers.ZeroAddress,
                ],
                liquidityWallet
            )
        ).to.be.revertedWithCustomError(
            { interface: (await ethers.getContractFactory("TenjiCoin", liquidityWallet)).interface },
            "ZeroAddress"
        );
    });
});
