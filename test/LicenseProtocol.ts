import { expect, hre } from "./setup";

describe("License protocol", function () {
  async function getProxyAdmin(proxy: any) {
    const { ethers } = await hre.network.connect();
    const adminAddress = await proxy.proxyAdmin();
    const proxyAdminFactory = await ethers.getContractFactory("LicenseProtocolProxyAdmin");

    return proxyAdminFactory.attach(adminAddress);
  }

  async function deployFixture({ linkToken = true }: { linkToken?: boolean } = {}) {
    const { network } = hre;
    const { ethers, networkHelpers } = await network.connect();
    const [admin, creator, buyer, receiver] = await ethers.getSigners();

    const proxyFactory = await ethers.getContractFactory("LicenseProtocolProxy");

    const registryImplFactory = await ethers.getContractFactory("LicenseRegistryUpgradeable");
    const registryImpl = await registryImplFactory.connect(admin).deploy();
    await registryImpl.waitForDeployment();

    const registryInit = registryImplFactory.interface.encodeFunctionData("initialize", [await admin.getAddress()]);
    const registryProxy = await proxyFactory
      .connect(admin)
      .deploy(await registryImpl.getAddress(), await admin.getAddress(), registryInit);
    await registryProxy.waitForDeployment();

    const registry = registryImplFactory.attach(await registryProxy.getAddress());

    const tokenImplFactory = await ethers.getContractFactory("LicenseTokenUpgradeable");
    const tokenImpl = await tokenImplFactory.connect(admin).deploy();
    await tokenImpl.waitForDeployment();

    const tokenInit = tokenImplFactory.interface.encodeFunctionData("initialize", [await registry.getAddress()]);
    const tokenProxy = await proxyFactory
      .connect(admin)
      .deploy(await tokenImpl.getAddress(), await admin.getAddress(), tokenInit);
    await tokenProxy.waitForDeployment();

    const token = tokenImplFactory.attach(await tokenProxy.getAddress());

    if (linkToken) {
      await registry.connect(admin).setLicenseToken(await token.getAddress());
    }

    const usdcFactory = await ethers.getContractFactory("MockUSDC");
    const usdc = await usdcFactory.connect(admin).deploy();
    await usdc.waitForDeployment();

    return { ethers, networkHelpers, admin, creator, buyer, receiver, registry, token, registryProxy, tokenProxy, usdc };
  }

  async function signLicenseOrder(
    registry: any,
    signer: any,
    order: {
      assetId: bigint | number;
      licenseTypeId: bigint | number;
      buyer: string;
      recipient: string;
      paymentToken: string;
      price: bigint | number;
      deadline: bigint | number;
      salt: bigint | number;
    },
  ) {
    const network = await hre.network.connect();
    const { ethers } = network;
    const chainId = await ethers.provider.getNetwork().then((data) => data.chainId);

    return signer.signTypedData(
      {
        name: "Auctoris Licensing Authority",
        version: "1",
        chainId,
        verifyingContract: await registry.getAddress(),
      },
      {
        SignedLicenseOrder: [
          { name: "assetId", type: "uint256" },
          { name: "licenseTypeId", type: "uint256" },
          { name: "buyer", type: "address" },
          { name: "recipient", type: "address" },
          { name: "paymentToken", type: "address" },
          { name: "price", type: "uint256" },
          { name: "deadline", type: "uint64" },
          { name: "salt", type: "uint256" },
        ],
      },
      order,
    );
  }

  it("deploys registry and token behind transparent ERC1967 proxies and supports core license flow", async function () {
    const { ethers, creator, buyer, registry, token } = await deployFixture();

    const price = ethers.parseEther("0.25");
    await registry.connect(creator).createAsset("ipfs://upgradeable-asset");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, 0, false, 0);
    await registry.connect(buyer).buyLicense(1, 0, { value: price });

    const tokenId = await registry.getTokenId(1, 0);
    expect(await token.balanceOf(await buyer.getAddress(), tokenId)).to.equal(1n);
    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(true);
  });

  it("creates an asset and sells a time-limited non-transferable license for ETH", async function () {
    const { ethers, creator, buyer, registry, token } = await deployFixture();
    const price = ethers.parseEther("1");
    const duration = 30 * 24 * 60 * 60;

    await registry.connect(creator).createAsset("ipfs://asset-1");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, duration, false, 500);

    const tokenId = await registry.getTokenId(1, 0);

    const creatorBalanceBefore = await ethers.provider.getBalance(await creator.getAddress());
    await registry.connect(buyer).buyLicense(1, 0, { value: price });
    const creatorBalanceAfter = await ethers.provider.getBalance(await creator.getAddress());

    expect(await token.balanceOf(await buyer.getAddress(), tokenId)).to.equal(1n);
    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(true);
    expect(await registry.getExpiration(await buyer.getAddress(), tokenId)).to.be.greaterThan(0);
    expect(creatorBalanceAfter - creatorBalanceBefore).to.equal(price);
  });

  it("supports direct ERC20 / USDC-style purchases", async function () {
    const { creator, buyer, registry, token, usdc } = await deployFixture();
    const price = 125_000_000n;

    await registry.connect(creator).createAsset("ipfs://asset-usdc");
    await registry.connect(creator).createLicenseType(1, price, await usdc.getAddress(), 0, false, 0);

    await usdc.mint(await buyer.getAddress(), price);
    await usdc.connect(buyer).approve(await registry.getAddress(), price);
    await registry.connect(buyer).buyLicense(1, 0);

    const tokenId = await registry.getTokenId(1, 0);
    expect(await token.balanceOf(await buyer.getAddress(), tokenId)).to.equal(1n);
    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(true);
  });

  it("exposes EIP-2981 royalty quotes through the token", async function () {
    const { ethers, creator, registry, token } = await deployFixture();

    await registry.connect(creator).createAsset("ipfs://asset-royalty");
    await registry.connect(creator).createLicenseType(1, ethers.parseEther("1"), ethers.ZeroAddress, 0, false, 750);

    const tokenId = await registry.getTokenId(1, 0);
    const salePrice = ethers.parseEther("2");
    const [receiver, royaltyAmount] = await token.royaltyInfo(tokenId, salePrice);

    expect(receiver).to.equal(await creator.getAddress());
    expect(royaltyAmount).to.equal((salePrice * 750n) / 10_000n);
  });

  it("blocks transfer when the license terms mark the token as non-transferable", async function () {
    const { ethers, creator, buyer, receiver, registry, token } = await deployFixture();
    const price = ethers.parseEther("0.2");

    await registry.connect(creator).createAsset("ipfs://asset-2");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, 0, false, 0);
    await registry.connect(buyer).buyLicense(1, 0, { value: price });

    const tokenId = await registry.getTokenId(1, 0);

    await expect(
      token
        .connect(buyer)
        .safeTransferFrom(await buyer.getAddress(), await receiver.getAddress(), tokenId, 1, "0x"),
    )
      .to.be.revertedWithCustomError(token, "TransferNotAllowed")
      .withArgs(tokenId);
  });

  it("allows transfer when the license terms mark the token as transferable", async function () {
    const { ethers, creator, buyer, receiver, registry, token } = await deployFixture();
    const price = ethers.parseEther("0.2");

    await registry.connect(creator).createAsset("ipfs://asset-3");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, 0, true, 0);
    await registry.connect(buyer).buyLicense(1, 0, { value: price });

    const tokenId = await registry.getTokenId(1, 0);

    await token
      .connect(buyer)
      .safeTransferFrom(await buyer.getAddress(), await receiver.getAddress(), tokenId, 1, "0x");

    expect(await token.balanceOf(await receiver.getAddress(), tokenId)).to.equal(1n);
    expect(await registry.hasValidLicense(await receiver.getAddress(), 1, 0)).to.equal(true);
    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(false);
  });

  it("expires a time-limited license after its duration elapses", async function () {
    const { ethers, creator, buyer, registry, networkHelpers } = await deployFixture();
    const price = ethers.parseEther("0.05");
    const duration = 7 * 24 * 60 * 60;

    await registry.connect(creator).createAsset("ipfs://asset-4");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, duration, false, 0);
    await registry.connect(buyer).buyLicense(1, 0, { value: price });

    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(true);

    await networkHelpers.time.increase(duration + 1);

    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(false);
  });

  it("renews an existing license without minting duplicate ERC1155 balance", async function () {
    const { ethers, creator, buyer, registry, token, networkHelpers } = await deployFixture();
    const price = ethers.parseEther("0.1");
    const duration = 3 * 24 * 60 * 60;

    await registry.connect(creator).createAsset("ipfs://asset-5");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, duration, false, 0);

    const tokenId = await registry.getTokenId(1, 0);

    await registry.connect(buyer).buyLicense(1, 0, { value: price });
    const firstExpiration = await registry.getExpiration(await buyer.getAddress(), tokenId);

    await networkHelpers.time.increase(24 * 60 * 60);
    await registry.connect(buyer).buyLicense(1, 0, { value: price });
    const secondExpiration = await registry.getExpiration(await buyer.getAddress(), tokenId);

    expect(await token.balanceOf(await buyer.getAddress(), tokenId)).to.equal(1n);
    expect(secondExpiration).to.be.greaterThan(firstExpiration);
  });

  it("supports batch purchase across ETH and ERC20 licenses", async function () {
    const { ethers, creator, buyer, receiver, registry, token, usdc } = await deployFixture();
    const ethPrice = ethers.parseEther("0.15");
    const usdcPrice = 42_000_000n;

    await registry.connect(creator).createAsset("ipfs://asset-batch-eth");
    await registry.connect(creator).createLicenseType(1, ethPrice, ethers.ZeroAddress, 0, false, 0);
    await registry.connect(creator).createAsset("ipfs://asset-batch-usdc");
    await registry.connect(creator).createLicenseType(2, usdcPrice, await usdc.getAddress(), 0, false, 0);

    await usdc.mint(await buyer.getAddress(), usdcPrice);
    await usdc.connect(buyer).approve(await registry.getAddress(), usdcPrice);

    await registry.connect(buyer).buyLicenses(
      [
        { assetId: 1, licenseTypeId: 0, recipient: await buyer.getAddress() },
        { assetId: 2, licenseTypeId: 0, recipient: await receiver.getAddress() },
      ],
      { value: ethPrice },
    );

    expect(await token.balanceOf(await buyer.getAddress(), await registry.getTokenId(1, 0))).to.equal(1n);
    expect(await token.balanceOf(await receiver.getAddress(), await registry.getTokenId(2, 0))).to.equal(1n);
  });

  it("executes a creator-signed off-chain order with ERC20 payment", async function () {
    const { ethers, creator, buyer, receiver, registry, token, usdc } = await deployFixture();
    const orderPrice = 50_000_000n;

    await registry.connect(creator).createAsset("ipfs://asset-order");
    await registry
      .connect(creator)
      .createLicenseType(1, ethers.parseEther("1"), ethers.ZeroAddress, 0, false, 0);

    await usdc.mint(await buyer.getAddress(), orderPrice);
    await usdc.connect(buyer).approve(await registry.getAddress(), orderPrice);

    const order = {
      assetId: 1,
      licenseTypeId: 0,
      buyer: await buyer.getAddress(),
      recipient: await receiver.getAddress(),
      paymentToken: await usdc.getAddress(),
      price: orderPrice,
      deadline: 0,
      salt: 77,
    };

    const signature = await signLicenseOrder(registry, creator, order);
    const digest = await registry.hashSignedLicenseOrder(order);

    await registry.connect(buyer).buyLicenseWithOrder(order, signature);

    expect(await registry.isOrderUsed(digest)).to.equal(true);
    expect(await token.balanceOf(await receiver.getAddress(), await registry.getTokenId(1, 0))).to.equal(1n);
    expect(await registry.hasValidLicense(await receiver.getAddress(), 1, 0)).to.equal(true);

    await expect(registry.connect(buyer).buyLicenseWithOrder(order, signature))
      .to.be.revertedWithCustomError(registry, "OrderAlreadyUsed")
      .withArgs(digest);
  });

  it("lets the creator pause and resume sales for an asset", async function () {
    const { ethers, creator, buyer, registry } = await deployFixture();
    const price = ethers.parseEther("0.03");

    await registry.connect(creator).createAsset("ipfs://asset-control");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, 0, false, 0);
    await registry.connect(creator).setAssetActive(1, false);

    await expect(registry.connect(buyer).buyLicense(1, 0, { value: price }))
      .to.be.revertedWithCustomError(registry, "AssetInactive")
      .withArgs(1);

    await registry.connect(creator).setAssetActive(1, true);

    await registry.connect(buyer).buyLicense(1, 0, { value: price });
  });

  it("lets the creator pause a specific license type without disabling the whole asset", async function () {
    const { ethers, creator, buyer, registry } = await deployFixture();
    const price = ethers.parseEther("0.03");

    await registry.connect(creator).createAsset("ipfs://asset-license-pause");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, 0, false, 0);
    await registry.connect(creator).setLicenseTypeActive(1, 0, false);

    await expect(registry.connect(buyer).buyLicense(1, 0, { value: price }))
      .to.be.revertedWithCustomError(registry, "LicenseTypeInactive")
      .withArgs(1, 0);
  });

  it("can revoke a purchased license and burn the holder token", async function () {
    const { ethers, creator, buyer, registry, token } = await deployFixture();
    const price = ethers.parseEther("0.04");

    await registry.connect(creator).createAsset("ipfs://asset-revoke");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, 0, false, 0);
    await registry.connect(buyer).buyLicense(1, 0, { value: price });

    const tokenId = await registry.getTokenId(1, 0);

    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(true);

    await registry.connect(creator).revokeLicense(await buyer.getAddress(), 1, 0);

    expect(await token.balanceOf(await buyer.getAddress(), tokenId)).to.equal(0n);
    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(false);
    expect(await registry.getExpiration(await buyer.getAddress(), tokenId)).to.equal(0);
  });

  it("supports batch revoke across multiple issued licenses", async function () {
    const { ethers, creator, buyer, registry, token } = await deployFixture();
    const price = ethers.parseEther("0.02");

    await registry.connect(creator).createAsset("ipfs://asset-batch-revoke-a");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, 0, false, 0);
    await registry.connect(creator).createAsset("ipfs://asset-batch-revoke-b");
    await registry.connect(creator).createLicenseType(2, price, ethers.ZeroAddress, 0, false, 0);

    await registry.connect(buyer).buyLicenses(
      [
        { assetId: 1, licenseTypeId: 0, recipient: await buyer.getAddress() },
        { assetId: 2, licenseTypeId: 0, recipient: await buyer.getAddress() },
      ],
      { value: price * 2n },
    );

    await registry.connect(creator).revokeLicenses([
      { user: await buyer.getAddress(), assetId: 1, licenseTypeId: 0 },
      { user: await buyer.getAddress(), assetId: 2, licenseTypeId: 0 },
    ]);

    expect(await token.balanceOf(await buyer.getAddress(), await registry.getTokenId(1, 0))).to.equal(0n);
    expect(await token.balanceOf(await buyer.getAddress(), await registry.getTokenId(2, 0))).to.equal(0n);
  });

  it("returns aggregated license state for integrations", async function () {
    const { ethers, creator, buyer, registry } = await deployFixture();
    const price = ethers.parseEther("0.05");
    const duration = 2 * 24 * 60 * 60;

    await registry.connect(creator).createAsset("ipfs://asset-state");
    await registry.connect(creator).createLicenseType(1, price, ethers.ZeroAddress, duration, false, 250);
    await registry.connect(buyer).buyLicense(1, 0, { value: price });

    const [tokenId, balance, expiration, valid] = await registry.getLicenseState(
      await buyer.getAddress(),
      1,
      0,
    );

    expect(tokenId).to.equal(await registry.getTokenId(1, 0));
    expect(balance).to.equal(1n);
    expect(expiration).to.be.greaterThan(0);
    expect(valid).to.equal(true);
  });

  it("uses asset metadata by default and supports license-specific metadata overrides", async function () {
    const { ethers, creator, registry, token } = await deployFixture();

    await registry.connect(creator).createAsset("ipfs://asset-default-metadata");
    await registry.connect(creator).createLicenseType(1, 0, ethers.ZeroAddress, 0, false, 0);

    const tokenId = await registry.getTokenId(1, 0);

    expect(await token.uri(tokenId)).to.equal("ipfs://asset-default-metadata");

    await registry.connect(creator).setLicenseMetadataURI(1, 0, "ipfs://license-specific-metadata");

    expect(await token.uri(tokenId)).to.equal("ipfs://license-specific-metadata");
  });

  it("allows transferring asset ownership to a new creator", async function () {
    const { creator, buyer, registry } = await deployFixture();

    await registry.connect(creator).createAsset("ipfs://asset-ownership");
    await registry.connect(creator).transferAssetCreator(1, await buyer.getAddress());

    await expect(registry.connect(creator).setAssetActive(1, false))
      .to.be.revertedWithCustomError(registry, "NotAssetCreator")
      .withArgs(1, await creator.getAddress());

    await registry.connect(buyer).setAssetActive(1, false);
  });

  it("forwards reads through LicenseChecker and validates its constructor input", async function () {
    const { ethers, creator, buyer, registry } = await deployFixture();
    const checkerFactory = await ethers.getContractFactory("LicenseChecker");

    await expect(checkerFactory.deploy(ethers.ZeroAddress))
      .to.be.revertedWithCustomError(checkerFactory, "InvalidRegistry")
      .withArgs(ethers.ZeroAddress);

    await registry.connect(creator).createAsset("ipfs://checker-asset");
    await registry.connect(creator).createLicenseType(1, ethers.parseEther("0.01"), ethers.ZeroAddress, 0, false, 0);
    await registry.connect(buyer).buyLicense(1, 0, { value: ethers.parseEther("0.01") });

    const checker = await checkerFactory.deploy(await registry.getAddress());
    await checker.waitForDeployment();

    const tokenId = await checker.getTokenId(1, 0);
    const expiration = await checker.getExpiration(await buyer.getAddress(), tokenId);
    const [stateTokenId, balance, stateExpiration, valid] = await checker.getLicenseState(
      await buyer.getAddress(),
      1,
      0,
    );

    expect(await checker.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(true);
    expect(tokenId).to.equal(await registry.getTokenId(1, 0));
    expect(expiration).to.equal(0n);
    expect(stateTokenId).to.equal(tokenId);
    expect(balance).to.equal(1n);
    expect(stateExpiration).to.equal(expiration);
    expect(valid).to.equal(true);
  });

  it("covers mock usdc utility behavior", async function () {
    const { buyer, usdc } = await deployFixture();

    expect(await usdc.decimals()).to.equal(6);

    await usdc.mint(await buyer.getAddress(), 123_456_789n);
    expect(await usdc.balanceOf(await buyer.getAddress())).to.equal(123_456_789n);
  });

  it("enforces token registry-only entrypoints and declares supported interfaces", async function () {
    const { ethers, buyer, token } = await deployFixture();

    await expect(token.connect(buyer).mint(await buyer.getAddress(), 1, 1))
      .to.be.revertedWithCustomError(token, "UnauthorizedRegistry")
      .withArgs(await buyer.getAddress());

    await expect(token.connect(buyer).burn(await buyer.getAddress(), 1, 1))
      .to.be.revertedWithCustomError(token, "UnauthorizedRegistry")
      .withArgs(await buyer.getAddress());

    expect(await token.supportsInterface("0xd9b67a26")).to.equal(true);
    expect(await token.supportsInterface("0x2a55205a")).to.equal(true);
    expect(await token.supportsInterface("0xffffffff")).to.equal(false);

    const [receiver, royaltyAmount] = await token.royaltyInfo(999n, ethers.parseEther("1"));
    expect(receiver).to.equal(ethers.ZeroAddress);
    expect(royaltyAmount).to.equal(0n);
  });

  it("rejects zero-registry token initialization through the proxy", async function () {
    const { ethers } = await hre.network.connect();
    const [admin] = await ethers.getSigners();
    const proxyFactory = await ethers.getContractFactory("LicenseProtocolProxy");
    const tokenImplFactory = await ethers.getContractFactory("LicenseTokenUpgradeable");
    const tokenImpl = await tokenImplFactory.connect(admin).deploy();
    await tokenImpl.waitForDeployment();

    const badInit = tokenImplFactory.interface.encodeFunctionData("initialize", [ethers.ZeroAddress]);

    await expect(proxyFactory.connect(admin).deploy(await tokenImpl.getAddress(), await admin.getAddress(), badInit))
      .to.be.revertedWithCustomError(tokenImplFactory, "InvalidRegistry")
      .withArgs(ethers.ZeroAddress);
  });

  it("updates asset and license configuration and exposes getters", async function () {
    const { ethers, creator, registry, usdc } = await deployFixture();

    await registry.connect(creator).createAsset("ipfs://asset-config");
    await registry.connect(creator).createLicenseType(1, 1_000n, ethers.ZeroAddress, 30, false, 150);

    await registry.connect(creator).setAssetMetadataURI(1, "ipfs://asset-config-updated");
    await registry
      .connect(creator)
      .updateLicenseTerms(1, 0, 2_500n, await usdc.getAddress(), 90, true, 300, false);

    const asset = await registry.getAsset(1);
    const terms = await registry.getLicenseTerms(1, 0);

    expect(asset.metadataURI).to.equal("ipfs://asset-config-updated");
    expect(asset.active).to.equal(true);
    expect(terms.price).to.equal(2_500n);
    expect(terms.paymentToken).to.equal(await usdc.getAddress());
    expect(terms.duration).to.equal(90n);
    expect(terms.transferable).to.equal(true);
    expect(terms.royaltyBps).to.equal(300n);
    expect(terms.active).to.equal(false);
  });

  it("rejects invalid asset and license administration calls", async function () {
    const { ethers, creator, buyer, registry } = await deployFixture();

    await expect(registry.getAsset(999))
      .to.be.revertedWithCustomError(registry, "AssetNotFound")
      .withArgs(999);

    await expect(registry.connect(creator).setAssetActive(999, false))
      .to.be.revertedWithCustomError(registry, "AssetNotFound")
      .withArgs(999);

    await expect(registry.connect(buyer).setLicenseToken(await buyer.getAddress()))
      .to.be.revertedWithCustomError(registry, "UnauthorizedAdmin")
      .withArgs(await buyer.getAddress());

    await registry.connect(creator).createAsset("ipfs://admin-guards");

    await expect(registry.connect(buyer).createLicenseType(1, 1n, ethers.ZeroAddress, 0, false, 0))
      .to.be.revertedWithCustomError(registry, "NotAssetCreator")
      .withArgs(1, await buyer.getAddress());

    await expect(registry.connect(creator).transferAssetCreator(1, ethers.ZeroAddress))
      .to.be.revertedWithCustomError(registry, "InvalidCreator")
      .withArgs(ethers.ZeroAddress);

    await expect(registry.connect(creator).createLicenseType(1, 1n, await buyer.getAddress(), 0, false, 0))
      .to.be.revertedWithCustomError(registry, "InvalidPaymentToken")
      .withArgs(await buyer.getAddress());

    await expect(registry.connect(creator).createLicenseType(1, 1n, ethers.ZeroAddress, 0, false, 10_001))
      .to.be.revertedWithCustomError(registry, "InvalidRoyaltyBps")
      .withArgs(10_001);

    await registry.connect(creator).createLicenseType(1, 1n, ethers.ZeroAddress, 0, false, 0);

    await expect(registry.getTokenId(1, 99))
      .to.be.revertedWithCustomError(registry, "LicenseTypeNotFound")
      .withArgs(1, 99);

    await expect(registry.getLicenseTerms(1, 99))
      .to.be.revertedWithCustomError(registry, "LicenseTypeNotFound")
      .withArgs(1, 99);

    await expect(registry.connect(creator).updateLicenseTerms(1, 99, 1n, ethers.ZeroAddress, 0, false, 0, true))
      .to.be.revertedWithCustomError(registry, "LicenseTypeNotFound")
      .withArgs(1, 99);

    await expect(registry.connect(creator).setLicenseTypeActive(1, 99, false))
      .to.be.revertedWithCustomError(registry, "LicenseTypeNotFound")
      .withArgs(1, 99);

    await expect(registry.connect(buyer).buyLicense(1, 99))
      .to.be.revertedWithCustomError(registry, "LicenseTypeNotFound")
      .withArgs(1, 99);
  });

  it("handles token linkage guards and pre-link read behavior", async function () {
    const { ethers, admin, creator, buyer, registry } = await deployFixture({ linkToken: false });

    await expect(registry.connect(admin).setLicenseToken(ethers.ZeroAddress))
      .to.be.revertedWithCustomError(registry, "InvalidLicenseToken")
      .withArgs(ethers.ZeroAddress);

    await registry.connect(creator).createAsset("ipfs://unlinked-asset");
    await registry.connect(creator).createLicenseType(1, 0, ethers.ZeroAddress, 0, false, 0);

    const tokenId = await registry.getTokenId(1, 0);
    const [stateTokenId, balance, expiration, valid] = await registry.getLicenseState(await buyer.getAddress(), 1, 0);

    expect(stateTokenId).to.equal(tokenId);
    expect(balance).to.equal(0n);
    expect(expiration).to.equal(0n);
    expect(valid).to.equal(false);
    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(false);

    await expect(registry.connect(buyer).buyLicense(1, 0))
      .to.be.revertedWithCustomError(registry, "LicenseTokenNotSet");

    await expect(registry.connect(buyer).syncLicenseTransfer(await buyer.getAddress(), await admin.getAddress(), tokenId, 1))
      .to.be.revertedWithCustomError(registry, "UnauthorizedLicenseToken")
      .withArgs(await buyer.getAddress());

    await registry.connect(admin).setLicenseToken(await admin.getAddress());

    await expect(registry.connect(admin).setLicenseToken(await buyer.getAddress()))
      .to.be.revertedWithCustomError(registry, "LicenseTokenAlreadySet")
      .withArgs(await admin.getAddress());

    await expect(registry.connect(admin).syncLicenseTransfer(await buyer.getAddress(), await admin.getAddress(), tokenId, 2))
      .to.be.revertedWithCustomError(registry, "UnsupportedTransferAmount")
      .withArgs(2);
  });

  it("returns false for invalid or inactive license checks and guards revoke when token is missing", async function () {
    const { ethers, creator, buyer, registry } = await deployFixture({ linkToken: false });

    await expect(registry.connect(creator).revokeLicense(await buyer.getAddress(), 999, 0))
      .to.be.revertedWithCustomError(registry, "AssetNotFound")
      .withArgs(999);

    await registry.connect(creator).createAsset("ipfs://validity-guards");
    await registry.connect(creator).createLicenseType(1, 0, ethers.ZeroAddress, 0, false, 0);

    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 99)).to.equal(false);

    await registry.connect(creator).setLicenseTypeActive(1, 0, false);
    expect(await registry.hasValidLicense(await buyer.getAddress(), 1, 0)).to.equal(false);

    await expect(registry.connect(creator).revokeLicense(await buyer.getAddress(), 1, 0))
      .to.be.revertedWithCustomError(registry, "LicenseTokenNotSet");
  });

  it("rejects malformed direct and batch payments", async function () {
    const { ethers, creator, buyer, receiver, registry, usdc } = await deployFixture();

    await expect(registry.connect(buyer).buyLicenses([], { value: 0 }))
      .to.be.revertedWithCustomError(registry, "EmptyBatch");

    await expect(registry.connect(buyer).buyLicense(999, 0, { value: 0 }))
      .to.be.revertedWithCustomError(registry, "AssetNotFound")
      .withArgs(999);

    await registry.connect(creator).createAsset("ipfs://payment-eth");
    await registry.connect(creator).createLicenseType(1, ethers.parseEther("0.4"), ethers.ZeroAddress, 0, false, 0);

    await expect(registry.connect(buyer).buyLicense(1, 0, { value: ethers.parseEther("0.1") }))
      .to.be.revertedWithCustomError(registry, "IncorrectPayment")
      .withArgs(ethers.parseEther("0.4"), ethers.parseEther("0.1"));

    await registry.connect(creator).createAsset("ipfs://payment-usdc");
    await registry.connect(creator).createLicenseType(2, 50_000_000n, await usdc.getAddress(), 0, false, 0);

    await expect(registry.connect(buyer).buyLicense(2, 0, { value: 1 }))
      .to.be.revertedWithCustomError(registry, "UnexpectedNativePayment")
      .withArgs(1);

    await usdc.mint(await buyer.getAddress(), 50_000_000n);
    await usdc.connect(buyer).approve(await registry.getAddress(), 50_000_000n);

    await expect(
      registry.connect(buyer).buyLicenses(
        [
          { assetId: 1, licenseTypeId: 0, recipient: await buyer.getAddress() },
          { assetId: 2, licenseTypeId: 0, recipient: await receiver.getAddress() },
        ],
        { value: ethers.parseEther("0.1") },
      ),
    )
      .to.be.revertedWithCustomError(registry, "IncorrectPayment")
      .withArgs(ethers.parseEther("0.4"), ethers.parseEther("0.1"));
  });

  it("validates signed-order edge cases", async function () {
    const { ethers, creator, buyer, receiver, registry, usdc } = await deployFixture();

    await registry.connect(creator).createAsset("ipfs://signed-order-guards");
    await registry.connect(creator).createLicenseType(1, 10n, ethers.ZeroAddress, 0, false, 0);

    const buyerAddress = await buyer.getAddress();
    const receiverAddress = await receiver.getAddress();

    const expiredOrder = {
      assetId: 1,
      licenseTypeId: 0,
      buyer: buyerAddress,
      recipient: receiverAddress,
      paymentToken: ethers.ZeroAddress,
      price: 10n,
      deadline: 1,
      salt: 1,
    };

    await expect(registry.connect(buyer).buyLicenseWithOrder(expiredOrder, "0x", { value: 10n }))
      .to.be.revertedWithCustomError(registry, "OrderExpired")
      .withArgs(1);

    const fixedBuyerOrder = {
      ...expiredOrder,
      deadline: 0,
      salt: 2,
      paymentToken: await usdc.getAddress(),
      price: 20_000_000n,
    };

    const fixedBuyerSignature = await signLicenseOrder(registry, creator, fixedBuyerOrder);

    await usdc.mint(buyerAddress, 20_000_000n);
    await usdc.connect(buyer).approve(await registry.getAddress(), 20_000_000n);

    await expect(registry.connect(receiver).buyLicenseWithOrder(fixedBuyerOrder, fixedBuyerSignature))
      .to.be.revertedWithCustomError(registry, "InvalidOrderBuyer")
      .withArgs(buyerAddress, receiverAddress);

    const invalidTokenOrder = {
      ...fixedBuyerOrder,
      salt: 3,
      paymentToken: receiverAddress,
    };
    const invalidTokenSignature = await signLicenseOrder(registry, creator, invalidTokenOrder);

    await expect(registry.connect(buyer).buyLicenseWithOrder(invalidTokenOrder, invalidTokenSignature))
      .to.be.revertedWithCustomError(registry, "InvalidPaymentToken")
      .withArgs(receiverAddress);

    const validOrder = {
      ...fixedBuyerOrder,
      salt: 4,
    };
    const validSignature = await signLicenseOrder(registry, creator, validOrder);

    await expect(registry.connect(buyer).buyLicenseWithOrder({ ...validOrder, price: 21_000_000n }, validSignature))
      .to.be.revertedWithCustomError(registry, "InvalidOrderSignature");
  });

  it("lets the owner administrate revocations while blocking unauthorized callers", async function () {
    const { ethers, admin, creator, buyer, receiver, registry, token } = await deployFixture();

    await registry.connect(creator).createAsset("ipfs://admin-revoke");
    await registry.connect(creator).createLicenseType(1, ethers.parseEther("0.05"), ethers.ZeroAddress, 0, true, 0);
    await registry.connect(buyer).buyLicense(1, 0, { value: ethers.parseEther("0.05") });

    await expect(registry.connect(buyer).revokeLicense(await buyer.getAddress(), 1, 0))
      .to.be.revertedWithCustomError(registry, "UnauthorizedAssetController")
      .withArgs(1, await buyer.getAddress());

    await expect(registry.connect(creator).revokeLicenses([]))
      .to.be.revertedWithCustomError(registry, "EmptyBatch");

    await expect(registry.connect(creator).revokeLicense(ethers.ZeroAddress, 1, 0))
      .to.be.revertedWithCustomError(registry, "InvalidLicenseHolder")
      .withArgs(ethers.ZeroAddress);

    await registry.connect(admin).revokeLicense(await buyer.getAddress(), 1, 0);
    expect(await token.balanceOf(await buyer.getAddress(), await registry.getTokenId(1, 0))).to.equal(0n);

    await registry.connect(admin).revokeLicense(await receiver.getAddress(), 1, 0);
    expect(await registry.getExpiration(await receiver.getAddress(), await registry.getTokenId(1, 0))).to.equal(0n);
  });

  it("prevents transferring a license to an address that already holds the same token", async function () {
    const { ethers, creator, buyer, receiver, registry, token } = await deployFixture();

    await registry.connect(creator).createAsset("ipfs://duplicate-holder");
    await registry.connect(creator).createLicenseType(1, ethers.parseEther("0.05"), ethers.ZeroAddress, 0, true, 0);

    await registry.connect(buyer).buyLicense(1, 0, { value: ethers.parseEther("0.05") });
    await registry.connect(receiver).buyLicense(1, 0, { value: ethers.parseEther("0.05") });

    const tokenId = await registry.getTokenId(1, 0);

    await expect(
      token
        .connect(buyer)
        .safeTransferFrom(await buyer.getAddress(), await receiver.getAddress(), tokenId, 1, "0x"),
    )
      .to.be.revertedWithCustomError(token, "DuplicateLicenseHolder")
      .withArgs(await receiver.getAddress(), tokenId);
  });

  it("covers metadata and royalty fallbacks for unknown or inactive records", async function () {
    const { ethers, creator, registry } = await deployFixture();

    expect(await registry.isLicenseTransferable(123n)).to.equal(false);

    await expect(registry.tokenURI(123n))
      .to.be.revertedWithCustomError(registry, "LicenseTypeNotFound")
      .withArgs(0, 123);

    const [receiver, royaltyAmount] = await registry.royaltyInfo(123n, ethers.parseEther("1"));
    expect(receiver).to.equal(ethers.ZeroAddress);
    expect(royaltyAmount).to.equal(0n);

    await registry.connect(creator).createAsset("ipfs://inactive-asset");
    await registry.connect(creator).createLicenseType(1, 0, ethers.ZeroAddress, 0, false, 0);
    await registry.connect(creator).setAssetActive(1, false);

    expect(await registry.hasValidLicense(await creator.getAddress(), 1, 0)).to.equal(false);
  });

  it("rejects expiration overflows during perpetual-renewal accounting", async function () {
    const { ethers, creator, buyer, registry } = await deployFixture();

    await registry.connect(creator).createAsset("ipfs://overflow");
    await registry.connect(creator).createLicenseType(1, 0, ethers.ZeroAddress, (2n ** 64n) - 1n, false, 0);

    await expect(registry.connect(buyer).buyLicense(1, 0))
      .to.be.revertedWithCustomError(registry, "ExpirationOverflow");
  });

  it("authorizes upgrades only for the proxy admin owner", async function () {
    const { admin, buyer, registry, token, registryProxy, tokenProxy } = await deployFixture();
    const { ethers } = await hre.network.connect();
    const registryProxyAdmin = await getProxyAdmin(registryProxy);
    const tokenProxyAdmin = await getProxyAdmin(tokenProxy);

    const registryImplFactory = await ethers.getContractFactory("LicenseRegistryUpgradeable");
    const nextRegistryImpl = await registryImplFactory.connect(admin).deploy();
    await nextRegistryImpl.waitForDeployment();

    await expect(registryProxyAdmin.connect(buyer).upgradeAndCall(await registry.getAddress(), await nextRegistryImpl.getAddress(), "0x"))
      .to.be.revertedWithCustomError(registryProxyAdmin, "OwnableUnauthorizedAccount")
      .withArgs(await buyer.getAddress());

    await registryProxyAdmin.connect(admin).upgradeAndCall(await registry.getAddress(), await nextRegistryImpl.getAddress(), "0x");

    const tokenImplFactory = await ethers.getContractFactory("LicenseTokenUpgradeable");
    const nextTokenImpl = await tokenImplFactory.connect(admin).deploy();
    await nextTokenImpl.waitForDeployment();

    await expect(tokenProxyAdmin.connect(buyer).upgradeAndCall(await token.getAddress(), await nextTokenImpl.getAddress(), "0x"))
      .to.be.revertedWithCustomError(tokenProxyAdmin, "OwnableUnauthorizedAccount")
      .withArgs(await buyer.getAddress());

    await tokenProxyAdmin.connect(admin).upgradeAndCall(await token.getAddress(), await nextTokenImpl.getAddress(), "0x");
  });
});
