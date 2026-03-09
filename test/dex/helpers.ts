/**
 * @file helpers.ts
 * @notice Shared deployment and scenario helpers for DEX tests.
 * @dev NatSpec-style comment for test documentation.
 */

import {createRequire} from "module";
import {hre, type HardhatEthers, type HardhatEthersSigner, type NetworkHelpers} from "../setup.js";

const require = createRequire(import.meta.url);
const proxyArtifact = require("@openzeppelin/contracts/build/contracts/ERC1967Proxy.json");

/**
 * @notice Runtime connection bundle for Hardhat network tests.
 */
export type Connection = {
    ethers: HardhatEthers;
    networkHelpers: NetworkHelpers;
};

/**
 * @notice Core test fixture return shape.
 */
export type DexFixture = {
    ethers: HardhatEthers;
    networkHelpers: NetworkHelpers;
    admin: HardhatEthersSigner;
    user1: HardhatEthersSigner;
    user2: HardhatEthersSigner;
    user3: HardhatEthersSigner;
    weth: any;
    tokenA: any;
    tokenB: any;
    tokenC: any;
    rewardToken: any;
    poolFactory: any;
    router: any;
    routerV2: any;
    oracle: any;
    feeCollector: any;
    flashLoanLimiter: any;
    governance: any;
    proxyFactory: any;
};

/**
 * @notice Connects to in-process Hardhat network.
 */
export async function getConnection(): Promise<Connection> {
    const connection = await hre.network.connect();
    const {ethers, networkHelpers} = connection;
    return {ethers, networkHelpers};
}

/**
 * @notice Deploys upgradeable contract via implementation + ERC1967Proxy.
 * @param ethers Hardhat ethers helper.
 * @param signer Deployment signer.
 * @param name Contract name.
 * @param initArgs Initializer arguments.
 */
export async function deployUpgradeable(
    ethers: HardhatEthers,
    signer: HardhatEthersSigner,
    name: string,
    initArgs: unknown[]
): Promise<any> {
    const implFactory = await ethers.getContractFactory(name, signer);
    const impl = await implFactory.deploy();
    await impl.waitForDeployment();

    const initData = implFactory.interface.encodeFunctionData("initialize", initArgs);

    const proxyFactory = new ethers.ContractFactory(proxyArtifact.abi, proxyArtifact.bytecode, signer);
    const proxy = await proxyFactory.deploy(await impl.getAddress(), initData);
    await proxy.waitForDeployment();

    return ethers.getContractAt(name, await proxy.getAddress(), signer);
}

/**
 * @notice Deploys full DEX stack used by tests.
 */
export async function deployDexFixture(): Promise<DexFixture> {
    const {ethers, networkHelpers} = await getConnection();
    const [admin, user1, user2, user3] = await ethers.getSigners();

    const tokenA = await ethers.deployContract("MockERC20", ["Token A", "TKA"], admin);
    const tokenB = await ethers.deployContract("MockERC20", ["Token B", "TKB"], admin);
    const tokenC = await ethers.deployContract("MockERC20", ["Token C", "TKC"], admin);
    const rewardToken = await ethers.deployContract("MockERC20", ["Reward", "RWD"], admin);
    const weth = await ethers.deployContract("MockWETH", admin);
    const proxyFactory = await ethers.deployContract("DEXTransparentProxyFactory", admin);

    const poolFactory = await deployUpgradeable(ethers, admin, "PoolFactory", [admin.address, await weth.getAddress()]);
    const router = await deployUpgradeable(
        ethers,
        admin,
        "Router",
        [admin.address, await poolFactory.getAddress(), await weth.getAddress()]
    );
    const routerV2 = await deployUpgradeable(
        ethers,
        admin,
        "RouterV2",
        [admin.address, await poolFactory.getAddress(), await router.getAddress()]
    );
    const oracle = await deployUpgradeable(ethers, admin, "PriceOracle", [admin.address]);
    const feeCollector = await deployUpgradeable(ethers, admin, "FeeCollector", [admin.address]);
    const flashLoanLimiter = await deployUpgradeable(ethers, admin, "FlashLoanLimiter", [admin.address, 3_000]);
    const governance = await deployUpgradeable(
        ethers,
        admin,
        "DEXGovernance",
        [admin.address, await poolFactory.getAddress(), 3600]
    );

    const mintAmount = ethers.parseEther("1000000");
    for (const signer of [admin, user1, user2, user3]) {
        await tokenA.mint(signer.address, mintAmount);
        await tokenB.mint(signer.address, mintAmount);
        await tokenC.mint(signer.address, mintAmount);
        await rewardToken.mint(signer.address, mintAmount);
    }

    await poolFactory.setFeeConfig(30, 5, await feeCollector.getAddress());
    await poolFactory.setFlashLoanLimiter(await flashLoanLimiter.getAddress());

    return {
        ethers,
        networkHelpers,
        admin,
        user1,
        user2,
        user3,
        weth,
        tokenA,
        tokenB,
        tokenC,
        rewardToken,
        poolFactory,
        router,
        routerV2,
        oracle,
        feeCollector,
        flashLoanLimiter,
        governance,
        proxyFactory
    };
}

/**
 * @notice Returns timestamp in future used as deadline.
 * @param networkHelpers Hardhat network helpers.
 * @param deltaSec Deadline offset in seconds.
 */
export async function deadlineFromNow(networkHelpers: NetworkHelpers, deltaSec = 3600): Promise<bigint> {
    const now = await networkHelpers.time.latest();
    return BigInt(now + deltaSec);
}

/**
 * @notice Adds liquidity to router for a token pair.
 */
export async function addLiquidityViaRouter(
    fixture: DexFixture,
    signer: HardhatEthersSigner,
    tokenX: any,
    tokenY: any,
    amountX: bigint,
    amountY: bigint
): Promise<string> {
    const deadline = await deadlineFromNow(fixture.networkHelpers);
    await tokenX.connect(signer).approve(await fixture.router.getAddress(), amountX);
    await tokenY.connect(signer).approve(await fixture.router.getAddress(), amountY);
    const tx = await fixture.router.connect(signer).addLiquidity(
        await tokenX.getAddress(),
        await tokenY.getAddress(),
        amountX,
        amountY,
        0,
        0,
        0,
        deadline
    );
    await tx.wait();
    return fixture.poolFactory.getPool(await tokenX.getAddress(), await tokenY.getAddress());
}
