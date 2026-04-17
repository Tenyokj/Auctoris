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

type ProxyAdminTarget = {
  label: "registry" | "token";
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

function resolveTargets(manifest: DeploymentManifest, scope: string): ProxyAdminTarget[] {
  const normalizedScope = scope.trim().toLowerCase();

  if (normalizedScope === "registry") {
    return [{ label: "registry", proxy: manifest.registryProxy, proxyAdmin: manifest.registryProxyAdmin }];
  }

  if (normalizedScope === "token") {
    return [{ label: "token", proxy: manifest.tokenProxy, proxyAdmin: manifest.tokenProxyAdmin }];
  }

  return [
    { label: "registry", proxy: manifest.registryProxy, proxyAdmin: manifest.registryProxyAdmin },
    { label: "token", proxy: manifest.tokenProxy, proxyAdmin: manifest.tokenProxyAdmin },
  ];
}

async function main() {
  const { ethers, networkName } = await hre.network.connect();
  const [deployer] = await ethers.getSigners();
  const safeAddress = process.env.SAFE_MULTISIG_ADDRESS?.trim();
  const scope = process.env.PROXY_ADMIN_SCOPE?.trim() ?? "all";

  if (!safeAddress) {
    throw new Error("SAFE_MULTISIG_ADDRESS is required");
  }
  if (!ethers.isAddress(safeAddress)) {
    throw new Error(`Invalid SAFE_MULTISIG_ADDRESS: ${safeAddress}`);
  }

  const manifest = loadManifest(networkName);
  const proxyAdminFactory = await ethers.getContractFactory("LicenseProtocolProxyAdmin");
  const targets = resolveTargets(manifest, scope);

  console.log(`Transferring Auctoris ProxyAdmin ownership on ${networkName}`);
  console.log(`Current signer: ${deployer.address}`);
  console.log(`New Safe owner: ${safeAddress}`);
  console.log(`Scope: ${scope}`);

  for (const target of targets) {
    const proxyAdmin = proxyAdminFactory.attach(target.proxyAdmin);
    const currentOwner = await proxyAdmin.owner();

    console.log("");
    console.log(`[${target.label}] proxy:       ${target.proxy}`);
    console.log(`[${target.label}] proxy admin: ${target.proxyAdmin}`);
    console.log(`[${target.label}] owner:       ${currentOwner}`);

    if (currentOwner.toLowerCase() === safeAddress.toLowerCase()) {
      console.log(`[${target.label}] already owned by the Safe, skipping`);
      continue;
    }

    if (currentOwner.toLowerCase() !== deployer.address.toLowerCase()) {
      throw new Error(
        `[${target.label}] signer ${deployer.address} is not the current ProxyAdmin owner ${currentOwner}`,
      );
    }

    const tx = await proxyAdmin.connect(deployer).transferOwnership(safeAddress);
    await tx.wait();

    console.log(`[${target.label}] ownership transferred in tx: ${tx.hash}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
