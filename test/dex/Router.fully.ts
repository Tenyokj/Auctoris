/**
 * @file Router.fully.ts
 * @notice Router liquidity/swap path handling, ETH flows, and guard coverage.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {addLiquidityViaRouter, deadlineFromNow, deployDexFixture} from "./helpers.js";

/** @notice describe: Router full coverage */
describe("Router", function () {
    /** @notice it: rejects direct ETH receive from non-WETH sender */
    it("rejects plain ETH transfers to router", async function () {
        const {user1, router} = await deployDexFixture();
        await expect(user1.sendTransaction({to: await router.getAddress(), value: 1n}))
            .to.be.revertedWithCustomError(router, "InvalidAddress");
    });

    /** @notice it: adds and removes ERC20 liquidity through router */
    it("adds and removes token-token liquidity", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB, router, poolFactory} = fixture;
        const deadline = await deadlineFromNow(fixture.networkHelpers);

        const amountA = ethers.parseEther("100");
        const amountB = ethers.parseEther("100");
        await tokenA.connect(user1).approve(await router.getAddress(), amountA);
        await tokenB.connect(user1).approve(await router.getAddress(), amountB);

        await expect(
            router.connect(user1).addLiquidity(
                await tokenA.getAddress(),
                await tokenB.getAddress(),
                amountA,
                amountB,
                0,
                0,
                0,
                deadline
            )
        ).to.emit(router, "RouterLiquidityAdded");

        const poolAddress = await poolFactory.getPool(await tokenA.getAddress(), await tokenB.getAddress());
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);
        const shares = await pool.balanceOf(user1.address);
        await pool.approve(await router.getAddress(), shares / 2n);

        await expect(
            router.connect(user1).removeLiquidity(
                await tokenA.getAddress(),
                await tokenB.getAddress(),
                shares / 2n,
                0,
                0,
                deadline
            )
        ).to.emit(router, "RouterLiquidityRemoved");
    });

    /** @notice it: adds/removes ETH liquidity and executes ETH side swaps */
    it("handles add/remove liquidity ETH and token-ETH swaps", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, user2, tokenA, weth, router, poolFactory} = fixture;
        const deadline = await deadlineFromNow(fixture.networkHelpers);

        const amountToken = ethers.parseEther("200");
        const amountEth = ethers.parseEther("20");
        await tokenA.connect(user1).approve(await router.getAddress(), amountToken);

        await expect(
            router.connect(user1).addLiquidityETH(
                await tokenA.getAddress(),
                amountToken,
                0,
                0,
                0,
                deadline,
                {value: amountEth}
            )
        ).to.emit(router, "RouterLiquidityAdded");

        const poolAddress = await poolFactory.getPool(await tokenA.getAddress(), await weth.getAddress());
        expect(poolAddress).to.not.equal(ethers.ZeroAddress);

        await tokenA.connect(user2).approve(await router.getAddress(), ethers.parseEther("10"));
        await expect(
            router.connect(user2).swapExactTokensForETH(
                ethers.parseEther("10"),
                0,
                [await tokenA.getAddress(), await weth.getAddress()],
                user2.address,
                deadline
            )
        ).to.emit(router, "RouterSwap");

        await expect(
            router.connect(user2).swapExactETHForTokens(
                0,
                [await weth.getAddress(), await tokenA.getAddress()],
                user2.address,
                deadline,
                {value: ethers.parseEther("1")}
            )
        ).to.emit(router, "RouterSwap");

        const poolAddressEth = await poolFactory.getPool(await tokenA.getAddress(), await weth.getAddress());
        const pool = await ethers.getContractAt("LiquidityPool", poolAddressEth, user1);
        const shares = await pool.balanceOf(user1.address);
        await pool.approve(await router.getAddress(), shares / 4n);
        await expect(
            router.connect(user1).removeLiquidityETH(await tokenA.getAddress(), shares / 4n, 0, 0, deadline)
        ).to.emit(router, "RouterLiquidityRemoved");
    });

    /** @notice it: performs multi-hop token swaps and hop-level minimum checks */
    it("supports multi-hop swaps and hop minimum constraints", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, user2, tokenA, tokenB, tokenC, router} = fixture;
        const deadline = await deadlineFromNow(fixture.networkHelpers);

        await addLiquidityViaRouter(fixture, user1, tokenA, tokenB, ethers.parseEther("1000"), ethers.parseEther("1000"));
        await addLiquidityViaRouter(fixture, user1, tokenB, tokenC, ethers.parseEther("1000"), ethers.parseEther("1000"));

        await tokenA.connect(user2).approve(await router.getAddress(), ethers.parseEther("10"));
        await expect(
            router.connect(user2).swapExactTokensForTokens(
                ethers.parseEther("10"),
                0,
                [await tokenA.getAddress(), await tokenB.getAddress(), await tokenC.getAddress()],
                user2.address,
                deadline
            )
        ).to.emit(router, "RouterSwap");

        await expect(
            router.connect(user2).swapExactTokensForTokensWithHopMin(
                ethers.parseEther("10"),
                0,
                [await tokenA.getAddress(), await tokenB.getAddress(), await tokenC.getAddress()],
                [1n], // wrong length
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InvalidHopMins");

        await tokenA.connect(user2).approve(await router.getAddress(), ethers.parseEther("10"));
        await expect(
            router.connect(user2).swapExactTokensForTokensWithHopMin(
                ethers.parseEther("10"),
                0,
                [await tokenA.getAddress(), await tokenB.getAddress(), await tokenC.getAddress()],
                [0n, 0n],
                user2.address,
                deadline
            )
        ).to.emit(router, "RouterSwap");
    });

    /** @notice it: validates path, slippage, deadline, and paused-state guards */
    it("reverts on invalid path constraints and paused protocol", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, user2, tokenA, tokenB, router, poolFactory} = fixture;
        const deadline = await deadlineFromNow(fixture.networkHelpers);

        await addLiquidityViaRouter(fixture, user1, tokenA, tokenB, ethers.parseEther("500"), ethers.parseEther("500"));
        await tokenA.connect(user2).approve(await router.getAddress(), ethers.parseEther("10"));

        await expect(
            router.connect(user2).swapExactTokensForTokens(
                ethers.parseEther("10"),
                ethers.parseEther("1000"),
                [await tokenA.getAddress(), await tokenB.getAddress()],
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InsufficientOutputAmount");

        await expect(
            router.connect(user2).swapExactTokensForTokens(
                ethers.parseEther("10"),
                0,
                [await tokenA.getAddress()],
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InvalidPath");

        await poolFactory.pause();
        await expect(
            router.connect(user2).swapExactTokensForTokens(
                ethers.parseEther("10"),
                0,
                [await tokenA.getAddress(), await tokenB.getAddress()],
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "ProtocolPaused");
    });

    /** @notice it: covers router argument validation and admin pause controls */
    it("covers misc validation and owner-only pause controls", async function () {
        const fixture = await deployDexFixture();
        const {ethers, admin, user1, tokenA, tokenB, weth, router} = fixture;
        const deadline = await deadlineFromNow(fixture.networkHelpers);

        await expect(
            router.connect(user1).pause()
        ).to.be.revertedWithCustomError(router, "OwnableUnauthorizedAccount").withArgs(user1.address);

        await expect(
            router.connect(user1).addLiquidity(
                await tokenA.getAddress(),
                await tokenB.getAddress(),
                0,
                1,
                0,
                0,
                0,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InsufficientAmount");

        await expect(
            router.removeLiquidity(await tokenA.getAddress(), await tokenB.getAddress(), 1, 0, 0, deadline)
        ).to.be.revertedWithCustomError(router, "PoolNotFound");
        await expect(
            router.removeLiquidityETH(await tokenA.getAddress(), 1, 0, 0, deadline)
        ).to.be.revertedWithCustomError(router, "PoolNotFound");

        await expect(
            router.swapExactTokensForTokens(
                1,
                0,
                [await tokenA.getAddress(), await tokenB.getAddress()],
                ethers.ZeroAddress,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InvalidAddress");

        await expect(
            router.swapExactETHForTokens(
                0,
                [await tokenA.getAddress(), await tokenB.getAddress()],
                admin.address,
                deadline,
                {value: 1n}
            )
        ).to.be.revertedWithCustomError(router, "InvalidPath");
        await expect(
            router.swapExactTokensForETH(
                1,
                0,
                [await tokenA.getAddress(), await tokenB.getAddress()],
                admin.address,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InvalidPath");
        await expect(
            router.swapExactTokensForETH(
                1,
                0,
                [await weth.getAddress(), await tokenA.getAddress(), await weth.getAddress()],
                ethers.ZeroAddress,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InvalidAddress");

        await expect(router.getAmountsOut(1, [await tokenA.getAddress()]))
            .to.be.revertedWithCustomError(router, "InvalidPath");
        await expect(
            router.swapExactTokensForTokens(1, 0, [await tokenA.getAddress(), await tokenB.getAddress()], admin.address, 1)
        ).to.be.revertedWithCustomError(router, "DeadlineExpired");

        await expect(router.addLiquidityETH(await tokenA.getAddress(), 1, 0, 0, 0, deadline, {value: 0}))
            .to.be.revertedWithCustomError(router, "InsufficientAmount");

        await router.pause();
        await expect(
            router.swapExactETHForTokens(0, [await weth.getAddress(), await tokenA.getAddress()], admin.address, deadline, {value: 1n})
        ).to.be.revertedWithCustomError(router, "EnforcedPause");
        await router.unpause();
    });

    /** @notice it: reverts when ETH refund recipient rejects transfer */
    it("reverts on addLiquidityETH refund transfer failure", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, weth, router} = fixture;

        const deadline = await deadlineFromNow(fixture.networkHelpers);
        await tokenA.connect(user1).approve(await router.getAddress(), ethers.parseEther("200"));
        await router.connect(user1).addLiquidityETH(
            await tokenA.getAddress(),
            ethers.parseEther("100"),
            0,
            0,
            0,
            deadline,
            {value: ethers.parseEther("10")}
        );

        const actor = await ethers.deployContract("MockEthRejector", user1);
        await tokenA.connect(user1).transfer(await actor.getAddress(), ethers.parseEther("20"));
        await actor.connect(user1).approveToken(await tokenA.getAddress(), await router.getAddress(), ethers.parseEther("20"));

        await expect(
            actor.connect(user1).callAddLiquidityETH(
                await router.getAddress(),
                await tokenA.getAddress(),
                ethers.parseEther("10"),
                0,
                0,
                0,
                deadline,
                {value: ethers.parseEther("5")}
            )
        ).to.be.revertedWithCustomError(router, "ExternalCallFailed");

        expect(await weth.balanceOf(await actor.getAddress())).to.equal(0n);
    });

    /** @notice it: covers swapETH and swapToETH slippage and ETH-transfer-fail branches */
    it("covers additional swap edge branches and getAmountsOut", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, user2, tokenA, tokenB, weth, router} = fixture;
        const deadline = await deadlineFromNow(fixture.networkHelpers);

        await addLiquidityViaRouter(fixture, user1, tokenA, tokenB, ethers.parseEther("500"), ethers.parseEther("500"));
        await tokenA.connect(user1).approve(await router.getAddress(), ethers.parseEther("100"));
        await router.connect(user1).addLiquidityETH(
            await tokenA.getAddress(),
            ethers.parseEther("100"),
            0,
            0,
            0,
            deadline,
            {value: ethers.parseEther("10")}
        );

        await expect(
            router.connect(user2).swapExactETHForTokens(
                ethers.parseEther("1000"),
                [await weth.getAddress(), await tokenA.getAddress()],
                user2.address,
                deadline,
                {value: ethers.parseEther("1")}
            )
        ).to.be.revertedWithCustomError(router, "InsufficientOutputAmount");
        await expect(
            router.connect(user2).swapExactETHForTokens(
                0,
                [await weth.getAddress(), await tokenA.getAddress()],
                ethers.ZeroAddress,
                deadline,
                {value: ethers.parseEther("1")}
            )
        ).to.be.revertedWithCustomError(router, "InvalidAddress");

        await tokenA.connect(user2).approve(await router.getAddress(), ethers.parseEther("5"));
        await expect(
            router.connect(user2).swapExactTokensForETH(
                ethers.parseEther("5"),
                ethers.parseEther("100"),
                [await tokenA.getAddress(), await weth.getAddress()],
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InsufficientOutputAmount");

        const rejector = await ethers.deployContract("MockEthRejector", user2);
        await tokenA.connect(user2).transfer(await rejector.getAddress(), ethers.parseEther("5"));
        await rejector.approveToken(await tokenA.getAddress(), await router.getAddress(), ethers.parseEther("5"));
        await expect(
            rejector.callSwapExactTokensForETH(
                await router.getAddress(),
                ethers.parseEther("5"),
                0,
                [await tokenA.getAddress(), await weth.getAddress()],
                deadline
            )
        ).to.be.revertedWithCustomError(router, "ExternalCallFailed");

        const amounts = await router.getAmountsOut(ethers.parseEther("1"), [await tokenA.getAddress(), await tokenB.getAddress()]);
        expect(amounts.length).to.equal(2);
        await expect(router.getAmountsOut(ethers.parseEther("1"), [await tokenA.getAddress(), await weth.getAddress(), await tokenB.getAddress()]))
            .to.be.revertedWithCustomError(router, "PoolNotFound");

        await tokenA.connect(user2).approve(await router.getAddress(), ethers.parseEther("5"));
        await expect(
            router.connect(user2).swapExactTokensForTokensWithHopMin(
                ethers.parseEther("5"),
                ethers.parseEther("100"),
                [await tokenA.getAddress(), await tokenB.getAddress()],
                [0n],
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InsufficientOutputAmount");

        await expect(
            router.connect(user2).swapExactTokensForTokensWithHopMin(
                ethers.parseEther("5"),
                0,
                [await tokenA.getAddress()],
                [],
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InvalidPath");
        await expect(
            router.connect(user2).swapExactTokensForTokensWithHopMin(
                ethers.parseEther("5"),
                0,
                [await tokenA.getAddress(), await tokenB.getAddress()],
                [0n],
                ethers.ZeroAddress,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "InvalidAddress");

        await tokenB.connect(user2).approve(await router.getAddress(), ethers.parseEther("1"));
        await expect(
            router.connect(user2).swapExactTokensForTokens(
                ethers.parseEther("1"),
                0,
                [await tokenB.getAddress(), await weth.getAddress()],
                user2.address,
                deadline
            )
        ).to.be.revertedWithCustomError(router, "PoolNotFound");
    });
});
