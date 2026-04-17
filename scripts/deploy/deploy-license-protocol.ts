import { mkdirSync, writeFileSync } from "fs";
import { join } from "path";
import hre from "hardhat";

const PROTOCOL_NAME = "Auctoris Licensing Authority";

async function main() {
  const { ethers, networkName } = await hre.network.connect();
  const [deployer] = await ethers.getSigners();
  const { chainId } = await ethers.provider.getNetwork();
  const normalizedNetworkName = networkName === "default" ? "hardhat" : networkName;

  console.log(`Deploying ${PROTOCOL_NAME} with deployer: ${deployer.address}`);
  console.log(`Target network: ${normalizedNetworkName} (${chainId})`);

  const proxyFactory = await ethers.getContractFactory("LicenseProtocolProxy");

  const registryImplFactory = await ethers.getContractFactory("LicenseRegistryUpgradeable");
  const registryImpl = await registryImplFactory.connect(deployer).deploy();
  await registryImpl.waitForDeployment();

  const registryInit = registryImplFactory.interface.encodeFunctionData("initialize", [deployer.address]);
  const registryProxy = await proxyFactory
    .connect(deployer)
    .deploy(await registryImpl.getAddress(), deployer.address, registryInit);
  await registryProxy.waitForDeployment();

  const registry = registryImplFactory.attach(await registryProxy.getAddress());
  const registryProxyAdmin = await registryProxy.proxyAdmin();

  const tokenImplFactory = await ethers.getContractFactory("LicenseTokenUpgradeable");
  const tokenImpl = await tokenImplFactory.connect(deployer).deploy();
  await tokenImpl.waitForDeployment();

  const tokenInit = tokenImplFactory.interface.encodeFunctionData("initialize", [await registry.getAddress()]);
  const tokenProxy = await proxyFactory
    .connect(deployer)
    .deploy(await tokenImpl.getAddress(), deployer.address, tokenInit);
  await tokenProxy.waitForDeployment();

  const token = tokenImplFactory.attach(await tokenProxy.getAddress());
  const tokenProxyAdmin = await tokenProxy.proxyAdmin();

  const linkTx = await registry.connect(deployer).setLicenseToken(await token.getAddress());
  await linkTx.wait();

  const deployment = {
    protocol: PROTOCOL_NAME,
    network: normalizedNetworkName,
    chainId: chainId.toString(),
    deployedAt: new Date().toISOString(),
    deployer: deployer.address,
    registryImplementation: await registryImpl.getAddress(),
    registryProxy: await registry.getAddress(),
    registryProxyAdmin,
    tokenImplementation: await tokenImpl.getAddress(),
    tokenProxy: await token.getAddress(),
    tokenProxyAdmin,
    linkTransactionHash: linkTx.hash,
  };

  mkdirSync(join(process.cwd(), "deployments"), { recursive: true });
  const deploymentPath = join(process.cwd(), "deployments", `${normalizedNetworkName}.json`);
  writeFileSync(deploymentPath, `${JSON.stringify(deployment, null, 2)}\n`);

  console.log("");
  console.log(`${PROTOCOL_NAME} deployment complete`);
  console.log(`Registry implementation: ${deployment.registryImplementation}`);
  console.log(`Registry proxy:          ${deployment.registryProxy}`);
  console.log(`Registry proxy admin:    ${deployment.registryProxyAdmin}`);
  console.log(`Token implementation:    ${deployment.tokenImplementation}`);
  console.log(`Token proxy:             ${deployment.tokenProxy}`);
  console.log(`Token proxy admin:       ${deployment.tokenProxyAdmin}`);
  console.log(`Deployment manifest:     ${deploymentPath}`);
  console.log("");
  console.log("Suggested verification commands:");
  console.log(
    `npx hardhat verify --network ${normalizedNetworkName} ${deployment.registryImplementation}`,
  );
  console.log(
    `npx hardhat verify --network ${normalizedNetworkName} ${deployment.tokenImplementation}`,
  );
  console.log(
    `npx hardhat verify --network ${normalizedNetworkName} ${deployment.registryProxy} "${deployment.registryImplementation}" "${deployer.address}" "${registryInit}"`,
  );
  console.log(
    `npx hardhat verify --network ${normalizedNetworkName} ${deployment.tokenProxy} "${deployment.tokenImplementation}" "${deployer.address}" "${tokenInit}"`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
