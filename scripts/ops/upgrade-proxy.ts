import { existsSync, readFileSync } from "fs";
import { join } from "path";
import hre from "hardhat";

type DeploymentManifest = {
  protocol: string;
  network: string;
  chainId: string;
  deployedAt: string;
  deployer: string;
  registryImplementation: string;
  registryProxy: string;
  registryProxyAdmin: string;
  tokenImplementation: string;
  tokenProxy: string;
  tokenProxyAdmin: string;
  linkTransactionHash: string;
};

type UpgradeTarget = {
  label: "registry" | "token";
  contractName: "LicenseRegistryUpgradeable" | "LicenseTokenUpgradeable";
  proxy: string;
  proxyAdmin: string;
};

function getManifestPath(networkName: string) {
  const overridePath = process.env.DEPLOYMENT_MANIFEST_PATH?.trim();
  if (overridePath) {
    return overridePath;
  }

  return join(process.cwd(), "deployments", `${networkName}.json`);
}

function loadManifest(networkName: string): DeploymentManifest {
  const manifestPath = getManifestPath(networkName);
  if (!existsSync(manifestPath)) {
    throw new Error(`Deployment manifest not found at: ${manifestPath}`);
  }

  return JSON.parse(readFileSync(manifestPath, "utf8")) as DeploymentManifest;
}

function resolveUpgradeTarget(
  manifest: DeploymentManifest,
  target: string | undefined,
): UpgradeTarget {
  const normalizedTarget = target?.trim().toLowerCase();

  if (normalizedTarget === "registry") {
    return {
      label: "registry",
      contractName: "LicenseRegistryUpgradeable",
      proxy: manifest.registryProxy,
      proxyAdmin: manifest.registryProxyAdmin,
    };
  }

  if (normalizedTarget === "token") {
    return {
      label: "token",
      contractName: "LicenseTokenUpgradeable",
      proxy: manifest.tokenProxy,
      proxyAdmin: manifest.tokenProxyAdmin,
    };
  }

  throw new Error("UPGRADE_TARGET must be set to 'registry' or 'token'");
}

async function main() {
  const { ethers, networkName } = await hre.network.connect();
  const [deployer] = await ethers.getSigners();
  const manifest = loadManifest(networkName);
  const target = resolveUpgradeTarget(manifest, process.env.UPGRADE_TARGET);
  const upgradeCalldata = process.env.UPGRADE_CALLDATA?.trim() || "0x";

  if (!ethers.isHexString(upgradeCalldata)) {
    throw new Error(`UPGRADE_CALLDATA must be hex calldata, received: ${upgradeCalldata}`);
  }

  const implementationFactory = await ethers.getContractFactory(target.contractName);
  const newImplementation = await implementationFactory.connect(deployer).deploy();
  await newImplementation.waitForDeployment();

  const newImplementationAddress = await newImplementation.getAddress();
  const proxyAdminFactory = await ethers.getContractFactory("LicenseProtocolProxyAdmin");
  const proxyAdmin = proxyAdminFactory.attach(target.proxyAdmin);
  const owner = await proxyAdmin.owner();
  const safePayload = proxyAdmin.interface.encodeFunctionData("upgradeAndCall", [
    target.proxy,
    newImplementationAddress,
    upgradeCalldata,
  ]);

  console.log(`Preparing ${target.label} upgrade on ${networkName}`);
  console.log(`Signer:             ${deployer.address}`);
  console.log(`Proxy:              ${target.proxy}`);
  console.log(`ProxyAdmin:         ${target.proxyAdmin}`);
  console.log(`ProxyAdmin owner:   ${owner}`);
  console.log(`New implementation: ${newImplementationAddress}`);
  console.log(`Call data:          ${upgradeCalldata}`);
  console.log("");
  console.log("Verification command:");
  console.log(`npx hardhat verify --network ${networkName} ${newImplementationAddress}`);

  if (owner.toLowerCase() === deployer.address.toLowerCase()) {
    const tx = await proxyAdmin.connect(deployer).upgradeAndCall(
      target.proxy,
      newImplementationAddress,
      upgradeCalldata,
    );
    await tx.wait();

    console.log("");
    console.log(`Upgrade executed directly in tx: ${tx.hash}`);
    return;
  }

  console.log("");
  console.log("ProxyAdmin is not owned by the current signer.");
  console.log("Use the following Safe transaction payload:");
  console.log(`to:    ${target.proxyAdmin}`);
  console.log("value: 0");
  console.log(`data:  ${safePayload}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
