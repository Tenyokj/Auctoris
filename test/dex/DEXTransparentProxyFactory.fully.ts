/**
 * @file DEXTransparentProxyFactory.fully.ts
 * @notice Transparent proxy stack deployment helper tests.
 * @dev NatSpec-style comment for test documentation.
 */

import {expect} from "../setup.js";
import {deployDexFixture} from "./helpers.js";

/** @notice describe: DEXTransparentProxyFactory */
describe("DEXTransparentProxyFactory", function () {
    /** @notice it: deploys proxy admin and transparent proxy stack */
    it("deploys transparent proxy stack", async function () {
        const fixture = await deployDexFixture();
        const {ethers, admin, proxyFactory} = fixture;

        const impl = await ethers.deployContract("FeeCollector", admin);
        const initData = impl.interface.encodeFunctionData("initialize", [admin.address]);

        await expect(proxyFactory.deployProxyStack(await impl.getAddress(), admin.address, initData))
            .to.emit(proxyFactory, "ProxyStackDeployed");
    });
});

