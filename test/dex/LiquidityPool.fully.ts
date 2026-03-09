/**
 * @file LiquidityPool.fully.ts
 * @notice LiquidityPool mint/burn/swap/flash-swap/TWAP edge-case coverage.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {addLiquidityViaRouter, deadlineFromNow, deployDexFixture} from "./helpers.js";

/** @notice describe: LiquidityPool full coverage */
describe("LiquidityPool", function () {
    /** @notice it: validates constructor guards and zero-supply remove path */
    it("validates constructor and zero-supply removeLiquidity", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, weth, poolFactory, tokenA} = fixture;

        await expect(ethers.deployContract("LiquidityPool", [ethers.ZeroAddress, await tokenA.getAddress(), await weth.getAddress(), await poolFactory.getAddress()], user1))
            .to.be.revertedWithCustomError(poolFactory, "InvalidToken");
        await expect(ethers.deployContract("LiquidityPool", [await tokenA.getAddress(), await tokenA.getAddress(), await weth.getAddress(), await poolFactory.getAddress()], user1))
            .to.be.revertedWithCustomError(poolFactory, "InvalidToken");
        await expect(ethers.deployContract("LiquidityPool", [await tokenA.getAddress(), await weth.getAddress(), ethers.ZeroAddress, await poolFactory.getAddress()], user1))
            .to.be.revertedWithCustomError(poolFactory, "InvalidWETH");
        await expect(ethers.deployContract("LiquidityPool", [await tokenA.getAddress(), await weth.getAddress(), await weth.getAddress(), ethers.ZeroAddress], user1))
            .to.be.revertedWithCustomError(poolFactory, "InvalidFactory");

        await poolFactory.createPool(await tokenA.getAddress(), await weth.getAddress());
        const poolAddress = await poolFactory.getPool(await tokenA.getAddress(), await weth.getAddress());
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);
        await expect(pool.removeLiquidity(1, 0, 0, await deadlineFromNow(fixture.networkHelpers)))
            .to.be.revertedWithCustomError(pool, "InsufficientLiquidity");
    });

    /** @notice it: validates direct addLiquidity input checks and receive guard */
    it("covers add-liquidity and receive validation", async function () {
        const fixture = await deployDexFixture();
        const {ethers, admin, user1, tokenA, tokenB, weth, poolFactory} = fixture;

        await poolFactory.createPool(await tokenA.getAddress(), await tokenB.getAddress());
        const poolAddress = await poolFactory.getPool(await tokenA.getAddress(), await tokenB.getAddress());
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);

        await expect(pool.addLiquidity(0, 1, 0, await deadlineFromNow(fixture.networkHelpers)))
            .to.be.revertedWithCustomError(pool, "ZeroAmount");

        await tokenA.connect(user1).approve(poolAddress, ethers.parseEther("10"));
        await tokenB.connect(user1).approve(poolAddress, ethers.parseEther("10"));
        await expect(
            pool.addLiquidity(
                ethers.parseEther("10"),
                ethers.parseEther("10"),
                0,
                await deadlineFromNow(fixture.networkHelpers)
            )
        ).to.emit(pool, "LiquidityAdded");

        await expect(user1.sendTransaction({to: poolAddress, value: 1n}))
            .to.be.revertedWithCustomError(pool, "EthNotSupported");

        await poolFactory.createPool(await tokenA.getAddress(), await weth.getAddress());
    });

    /** @notice it: mints initial liquidity with locked MINIMUM_LIQUIDITY and supports remove */
    it("mints and burns LP liquidity correctly", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB} = fixture;
        const amountA = ethers.parseEther("100");
        const amountB = ethers.parseEther("100");

        const poolAddress = await addLiquidityViaRouter(fixture, user1, tokenA, tokenB, amountA, amountB);
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);

        const userShares = await pool.balanceOf(user1.address);
        const totalShares = await pool.totalSupply();
        const minLiquidity = await pool.MINIMUM_LIQUIDITY();
        expect(totalShares).to.equal(userShares + minLiquidity);

        const deadline = await deadlineFromNow(fixture.networkHelpers);
        await pool.connect(user1).approve(poolAddress, userShares / 2n);
        await expect(pool.connect(user1).removeLiquidity(userShares / 2n, 0, 0, deadline))
            .to.emit(pool, "LiquidityRemoved");

        await expect(pool.connect(user1).removeLiquidity(0, 0, 0, deadline))
            .to.be.revertedWithCustomError(pool, "ZeroAmount");
    });

    /** @notice it: executes exact-input swap from pre-transferred balances and emits fee event */
    it("swaps using balance-delta input and pays protocol fee", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB, feeCollector} = fixture;
        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("1000"),
            ethers.parseEther("1000")
        );
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);

        const amountIn = ethers.parseEther("10");
        await tokenA.connect(user1).transfer(poolAddress, amountIn);

        const feeBalanceBefore = await tokenA.balanceOf(await feeCollector.getAddress());
        const deadline = await deadlineFromNow(fixture.networkHelpers);
        await expect(pool.connect(user1).swap(await tokenA.getAddress(), 0, deadline))
            .to.emit(pool, "SwapExecuted");
        const feeBalanceAfter = await tokenA.balanceOf(await feeCollector.getAddress());

        expect(feeBalanceAfter).to.be.gt(feeBalanceBefore);
    });

    /** @notice it: rejects invalid swaps and expired operations */
    it("rejects invalid token, zero input delta, and expired deadline", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB, tokenC} = fixture;
        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("100"),
            ethers.parseEther("100")
        );
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);

        const pastDeadline = 1n;
        await expect(pool.connect(user1).swap(await tokenA.getAddress(), 0, pastDeadline))
            .to.be.revertedWithCustomError(pool, "DeadlineExpired");

        const deadline = await deadlineFromNow(fixture.networkHelpers);
        await expect(pool.connect(user1).swap(await tokenC.getAddress(), 0, deadline))
            .to.be.revertedWithCustomError(pool, "InvalidToken");
        await expect(pool.connect(user1).swap(await tokenA.getAddress(), 0, deadline))
            .to.be.revertedWithCustomError(pool, "InsufficientInputAmount");
    });

    /** @notice it: supports sync and skim for balance/reserve reconciliation */
    it("supports sync and skim", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, user2, tokenA, tokenB} = fixture;
        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("100"),
            ethers.parseEther("100")
        );
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);

        await tokenA.connect(user2).transfer(poolAddress, ethers.parseEther("5"));
        await tokenB.connect(user2).transfer(poolAddress, ethers.parseEther("3"));
        await expect(pool.sync()).to.emit(pool, "Synced");

        await tokenA.connect(user2).transfer(poolAddress, ethers.parseEther("1"));
        await tokenB.connect(user2).transfer(poolAddress, ethers.parseEther("1"));
        await expect(pool.skim(user2.address)).to.emit(pool, "Skimmed");
    });

    /** @notice it: performs successful flash swap callback flow */
    it("executes flash swap with callback repayment", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB} = fixture;
        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("1000"),
            ethers.parseEther("1000")
        );
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);

        const callee = await ethers.deployContract("MockFlashSwapCallee", user1);
        const poolTokenA = await pool.tokenA();
        const poolTokenB = await pool.tokenB();
        await tokenA.mint(await callee.getAddress(), ethers.parseEther("5"));
        await tokenB.mint(await callee.getAddress(), ethers.parseEther("5"));
        await callee.configure(poolTokenA, poolTokenB, ethers.parseEther("1"), 0, false);

        const reserveBefore = await pool.reserveA();
        const deadline = await deadlineFromNow(fixture.networkHelpers);
        await pool.flashSwap(ethers.parseEther("10"), 0, await callee.getAddress(), "0x1234", deadline);
        const reserveAfter = await pool.reserveA();
        expect(reserveAfter).to.be.gt(reserveBefore);
    });

    /** @notice it: rejects under-repaid flash swap and enforces limiter check */
    it("rejects bad flash swap repayment and limiter overflow", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB, poolFactory, flashLoanLimiter} = fixture;
        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("100"),
            ethers.parseEther("100")
        );
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);

        const callee = await ethers.deployContract("MockFlashSwapCallee", user1);
        await callee.configure(await tokenA.getAddress(), await tokenB.getAddress(), 0, 0, true);

        const deadline = await deadlineFromNow(fixture.networkHelpers);
        await expect(pool.flashSwap(ethers.parseEther("1"), 0, await callee.getAddress(), "0x", deadline))
            .to.be.revertedWithCustomError(pool, "InsufficientInputAmount");

        await flashLoanLimiter.setPoolLimit(poolAddress, 100); // 1%
        await poolFactory.setFlashLoanLimiter(await flashLoanLimiter.getAddress());
        await expect(pool.flashSwap(ethers.parseEther("2"), 0, await callee.getAddress(), "0x", deadline))
            .to.be.revertedWithCustomError(pool, "LimitExceeded");
    });

    /** @notice it: covers flash swap zero-recipient/zero-out and tokenB-out branches */
    it("covers additional flash swap branches", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB} = fixture;
        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("500"),
            ethers.parseEther("500")
        );
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);
        const deadline = await deadlineFromNow(fixture.networkHelpers);

        await expect(pool.flashSwap(0, 0, user1.address, "0x", deadline))
            .to.be.revertedWithCustomError(pool, "InvalidFlashSwap");
        await expect(pool.flashSwap(1, 0, ethers.ZeroAddress, "0x", deadline))
            .to.be.revertedWithCustomError(pool, "InvalidRecipient");
        await expect(pool.flashSwap(ethers.parseEther("1000"), 0, user1.address, "0x", deadline))
            .to.be.revertedWithCustomError(pool, "InsufficientLiquidity");

        const callee = await ethers.deployContract("MockFlashSwapCallee", user1);
        const poolTokenA = await pool.tokenA();
        const poolTokenB = await pool.tokenB();
        await tokenA.mint(await callee.getAddress(), ethers.parseEther("10"));
        await tokenB.mint(await callee.getAddress(), ethers.parseEther("10"));
        await callee.configure(poolTokenA, poolTokenB, 0, ethers.parseEther("1"), false);
        await pool.flashSwap(0, ethers.parseEther("2"), await callee.getAddress(), "0x1234", deadline);
    });

    /** @notice it: blocks pool operations when factory is paused */
    it("blocks pool methods when factory is paused", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB, poolFactory} = fixture;
        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("100"),
            ethers.parseEther("100")
        );
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);

        await poolFactory.pause();

        const deadline = await deadlineFromNow(fixture.networkHelpers);
        await tokenA.connect(user1).transfer(poolAddress, ethers.parseEther("1"));
        await expect(pool.swap(await tokenA.getAddress(), 0, deadline))
            .to.be.revertedWithCustomError(pool, "ProtocolPaused");
        await expect(pool.flashSwap(1, 0, user1.address, "0x", deadline))
            .to.be.revertedWithCustomError(pool, "ProtocolPaused");
    });

    /** @notice it: covers quote/getAmountOut/preview and ETH helper branches */
    it("covers view helpers and ETH swap helper guards", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB, weth, poolFactory} = fixture;
        const poolAddress = await addLiquidityViaRouter(
            fixture,
            user1,
            tokenA,
            tokenB,
            ethers.parseEther("100"),
            ethers.parseEther("100")
        );
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);

        await expect(pool.quote(0, 1, 1)).to.be.revertedWithCustomError(pool, "InsufficientLiquidity");
        await expect(pool.getAmountOut(0, 1, 1)).to.be.revertedWithCustomError(pool, "ZeroAmount");
        await expect(pool.previewSwap(await weth.getAddress(), 1)).to.be.revertedWithCustomError(pool, "InvalidToken");
        await expect(pool.skim(ethers.ZeroAddress)).to.be.revertedWithCustomError(pool, "InvalidRecipient");

        await poolFactory.createPool(await tokenA.getAddress(), await weth.getAddress());
        const poolEthAddress = await poolFactory.getPool(await tokenA.getAddress(), await weth.getAddress());
        const poolEth = await ethers.getContractAt("LiquidityPool", poolEthAddress, user1);

        await tokenA.connect(user1).approve(poolEthAddress, ethers.parseEther("10"));
        await weth.connect(user1).approve(poolEthAddress, ethers.parseEther("10"));
        await tokenA.connect(user1).transfer(poolEthAddress, ethers.parseEther("10"));
        await weth.connect(user1).deposit({value: ethers.parseEther("10")});
        await weth.connect(user1).transfer(poolEthAddress, ethers.parseEther("10"));
        await poolEth.addLiquidityFromBalances(0, await deadlineFromNow(fixture.networkHelpers));

        await expect(poolEth.swapExactETHForTokens(0, await deadlineFromNow(fixture.networkHelpers), {value: ethers.parseEther("0.1")}))
            .to.emit(poolEth, "SwapEthForToken");

        await tokenA.connect(user1).approve(poolEthAddress, ethers.parseEther("1"));
        await expect(
            poolEth.swapExactTokensForETH(await tokenA.getAddress(), ethers.parseEther("1"), 0, await deadlineFromNow(fixture.networkHelpers))
        ).to.emit(poolEth, "SwapTokenForEth");

        await expect(poolEth.swapExactETHForTokens(0, await deadlineFromNow(fixture.networkHelpers), {value: 0}))
            .to.be.revertedWithCustomError(poolEth, "ZeroAmount");
        await expect(pool.swapExactETHForTokens(0, await deadlineFromNow(fixture.networkHelpers), {value: 1}))
            .to.be.revertedWithCustomError(pool, "EthNotSupported");
        await expect(poolEth.swapExactTokensForETH(await weth.getAddress(), 1, 0, await deadlineFromNow(fixture.networkHelpers)))
            .to.be.revertedWithCustomError(poolEth, "InvalidToken");
        await expect(poolEth.swapExactTokensForETH(await tokenA.getAddress(), 0, 0, await deadlineFromNow(fixture.networkHelpers)))
            .to.be.revertedWithCustomError(poolEth, "ZeroAmount");

        await expect(pool.removeLiquidity(1, ethers.parseEther("1"), ethers.parseEther("1"), await deadlineFromNow(fixture.networkHelpers)))
            .to.be.revertedWithCustomError(pool, "SlippageExceeded");

        const rejector = await ethers.deployContract("MockEthRejector", user1);
        await tokenA.connect(user1).transfer(await rejector.getAddress(), ethers.parseEther("1"));
        await rejector.approveToken(await tokenA.getAddress(), poolEthAddress, ethers.parseEther("1"));
        await expect(
            rejector.callPoolSwapExactTokensForETH(
                poolEthAddress,
                await tokenA.getAddress(),
                ethers.parseEther("1"),
                0,
                await deadlineFromNow(fixture.networkHelpers)
            )
        ).to.be.revertedWith("POOL_SWAP_FAILED");

        expect(await poolEth.quote(ethers.parseEther("1"), ethers.parseEther("10"), ethers.parseEther("20")))
            .to.equal(ethers.parseEther("2"));
        await expect(poolEth.getAmountOut(1, 0, 1)).to.be.revertedWithCustomError(poolEth, "InsufficientLiquidity");
        await poolEth.previewSwap(await weth.getAddress(), 1);
    });

    /** @notice it: covers mint/swap edge branches for tiny/empty states */
    it("covers tiny-liquidity and zero-reserve swap branches", async function () {
        const fixture = await deployDexFixture();
        const {ethers, user1, tokenA, tokenB, poolFactory} = fixture;

        await poolFactory.createPool(await tokenA.getAddress(), await tokenB.getAddress());
        const poolAddress = await poolFactory.getPool(await tokenA.getAddress(), await tokenB.getAddress());
        const pool = await ethers.getContractAt("LiquidityPool", poolAddress, user1);

        await tokenA.connect(user1).approve(poolAddress, 1);
        await tokenB.connect(user1).approve(poolAddress, 1);
        await expect(pool.addLiquidity(1, 1, 0, await deadlineFromNow(fixture.networkHelpers)))
            .to.be.revertedWithCustomError(pool, "InsufficientLiquidity");

        await tokenA.connect(user1).transfer(poolAddress, 1);
        await expect(pool.swap(await tokenA.getAddress(), 0, await deadlineFromNow(fixture.networkHelpers)))
            .to.be.revertedWithCustomError(pool, "InsufficientLiquidity");

        await expect(pool.addLiquidityFromBalances(1, await deadlineFromNow(fixture.networkHelpers)))
            .to.be.revertedWithCustomError(pool, "ZeroAmount");
    });
});
