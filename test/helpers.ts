/**
 * @file helpers.ts
 * @notice Shared deployment and scenario helpers for DEX tests.
 * @dev NatSpec-style comment for test documentation.
 */

import {hre, type HardhatEthers, type HardhatEthersSigner, type NetworkHelpers} from "./setup.js";


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