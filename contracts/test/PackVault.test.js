const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("PackVault", function () {
  async function deployPackVaultFixture() {
    const [owner, user1, user2, operator] = await ethers.getSigners();

    // Deploy mock tokens
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const usdc = await MockERC20.deploy("USD Coin", "USDC", 6);
    const weth = await MockERC20.deploy("Wrapped ETH", "WETH", 18);
    const wbtc = await MockERC20.deploy("Wrapped BTC", "WBTC", 8);
    const apt = await MockERC20.deploy("Aptos", "APT", 8);

    // Deploy mock oracle
    const MockPriceOracle = await ethers.getContractFactory("MockPriceOracle");
    const priceOracle = await MockPriceOracle.deploy();

    // Set prices (in USDC with 18 decimals)
    await priceOracle.setPrice(await weth.getAddress(), ethers.parseUnits("3000", 18)); // $3000
    await priceOracle.setPrice(await wbtc.getAddress(), ethers.parseUnits("60000", 18)); // $60000
    await priceOracle.setPrice(await apt.getAddress(), ethers.parseUnits("10", 18)); // $10

    // Deploy mock Kana router
    const MockKanaRouter = await ethers.getContractFactory("MockKanaRouter");
    const kanaRouter = await MockKanaRouter.deploy();

    // Deploy PackVault
    const PackVault = await ethers.getContractFactory("PackVault");
    const packVault = await PackVault.deploy(
      await priceOracle.getAddress(),
      await kanaRouter.getAddress(),
      ethers.ZeroAddress, // paymaster
      await usdc.getAddress()
    );

    // Mint tokens to users
    await usdc.mint(user1.address, ethers.parseUnits("100000", 6)); // 100k USDC
    await usdc.mint(user2.address, ethers.parseUnits("50000", 6)); // 50k USDC

    // Fund Kana router with tokens for swaps
    await weth.mint(await kanaRouter.getAddress(), ethers.parseUnits("1000", 18));
    await wbtc.mint(await kanaRouter.getAddress(), ethers.parseUnits("10", 8));
    await apt.mint(await kanaRouter.getAddress(), ethers.parseUnits("10000", 8));

    return { 
      packVault, 
      usdc, 
      weth, 
      wbtc, 
      apt,
      priceOracle, 
      kanaRouter, 
      owner, 
      user1, 
      user2,
      operator 
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { packVault, owner } = await loadFixture(deployPackVaultFixture);
      expect(await packVault.owner()).to.equal(owner.address);
    });

    it("Should set the correct USDC address", async function () {
      const { packVault, usdc } = await loadFixture(deployPackVaultFixture);
      expect(await packVault.USDC()).to.equal(await usdc.getAddress());
    });

    it("Should set the correct oracle and router", async function () {
      const { packVault, priceOracle, kanaRouter } = await loadFixture(deployPackVaultFixture);
      expect(await packVault.priceOracle()).to.equal(await priceOracle.getAddress());
      expect(await packVault.kanaRouter()).to.equal(await kanaRouter.getAddress());
    });
  });

  describe("Pack Creation", function () {
    it("Should create a new pack with valid allocations", async function () {
      const { packVault, weth, wbtc, owner } = await loadFixture(deployPackVaultFixture);

      const allocations = [
        { tokenAddress: await weth.getAddress(), weightBps: 5000, currentBalance: 0 },
        { tokenAddress: await wbtc.getAddress(), weightBps: 5000, currentBalance: 0 }
      ];

      await expect(packVault.createPack("test_pack", "Test Pack", allocations))
        .to.emit(packVault, "PackCreated")
        .withArgs("test_pack", "Test Pack", await ethers.provider.getBlock('latest').then(b => b.timestamp + 1));

      const pack = await packVault.packs("test_pack");
      expect(pack.active).to.be.true;
      expect(pack.name).to.equal("Test Pack");
    });

    it("Should reject pack with weights not summing to 100%", async function () {
      const { packVault, weth, wbtc } = await loadFixture(deployPackVaultFixture);

      const allocations = [
        { tokenAddress: await weth.getAddress(), weightBps: 4000, currentBalance: 0 },
        { tokenAddress: await wbtc.getAddress(), weightBps: 5000, currentBalance: 0 }
      ];

      await expect(
        packVault.createPack("bad_pack", "Bad Pack", allocations)
      ).to.be.revertedWith("Weights must sum to 100%");
    });

    it("Should reject duplicate pack creation", async function () {
      const { packVault, weth, wbtc } = await loadFixture(deployPackVaultFixture);

      const allocations = [
        { tokenAddress: await weth.getAddress(), weightBps: 5000, currentBalance: 0 },
        { tokenAddress: await wbtc.getAddress(), weightBps: 5000, currentBalance: 0 }
      ];

      await packVault.createPack("test_pack", "Test Pack", allocations);

      await expect(
        packVault.createPack("test_pack", "Test Pack 2", allocations)
      ).to.be.revertedWith("Pack already exists");
    });

    it("Should only allow owner to create packs", async function () {
      const { packVault, weth, wbtc, user1 } = await loadFixture(deployPackVaultFixture);

      const allocations = [
        { tokenAddress: await weth.getAddress(), weightBps: 5000, currentBalance: 0 },
        { tokenAddress: await wbtc.getAddress(), weightBps: 5000, currentBalance: 0 }
      ];

      await expect(
        packVault.connect(user1).createPack("test_pack", "Test Pack", allocations)
      ).to.be.revertedWithCustomError(packVault, "OwnableUnauthorizedAccount");
    });
  });

  describe("Deposits", function () {
    async function setupPackFixture() {
      const fixture = await deployPackVaultFixture();
      const { packVault, weth, wbtc, apt } = fixture;

      // Create Bluechip pack: 40% ETH, 30% BTC, 30% APT
      const allocations = [
        { tokenAddress: await weth.getAddress(), weightBps: 4000, currentBalance: 0 },
        { tokenAddress: await wbtc.getAddress(), weightBps: 3000, currentBalance: 0 },
        { tokenAddress: await apt.getAddress(), weightBps: 3000, currentBalance: 0 }
      ];

      await packVault.createPack("bluechip", "Bluechip Pack", allocations);

      return fixture;
    }

    it("Should allow deposit and mint shares", async function () {
      const { packVault, usdc, user1 } = await loadFixture(setupPackFixture);

      const depositAmount = ethers.parseUnits("5000", 6); // 5000 USDC

      // Approve USDC
      await usdc.connect(user1).approve(await packVault.getAddress(), depositAmount);

      // Deposit
      const depositParams = {
        packId: "bluechip",
        usdcAmount: depositAmount,
        userSmartAccount: user1.address,
        referenceId: ethers.id("ref123")
      };

      await expect(packVault.connect(user1).deposit(depositParams))
        .to.emit(packVault, "PackDeposit");

      // Check shares
      const shares = await packVault.userShares("bluechip", user1.address);
      expect(shares).to.be.gt(0);
    });

    it("Should handle multiple user deposits correctly", async function () {
      const { packVault, usdc, user1, user2 } = await loadFixture(setupPackFixture);

      const amount1 = ethers.parseUnits("5000", 6);
      const amount2 = ethers.parseUnits("3000", 6);

      // User1 deposits
      await usdc.connect(user1).approve(await packVault.getAddress(), amount1);
      await packVault.connect(user1).deposit({
        packId: "bluechip",
        usdcAmount: amount1,
        userSmartAccount: user1.address,
        referenceId: ethers.id("ref1")
      });

      // User2 deposits
      await usdc.connect(user2).approve(await packVault.getAddress(), amount2);
      await packVault.connect(user2).deposit({
        packId: "bluechip",
        usdcAmount: amount2,
        userSmartAccount: user2.address,
        referenceId: ethers.id("ref2")
      });

      const shares1 = await packVault.userShares("bluechip", user1.address);
      const shares2 = await packVault.userShares("bluechip", user2.address);

      expect(shares1).to.be.gt(shares2); // User1 deposited more
    });

    it("Should reject deposit to non-existent pack", async function () {
      const { packVault, usdc, user1 } = await loadFixture(setupPackFixture);

      const depositAmount = ethers.parseUnits("5000", 6);
      await usdc.connect(user1).approve(await packVault.getAddress(), depositAmount);

      await expect(
        packVault.connect(user1).deposit({
          packId: "nonexistent",
          usdcAmount: depositAmount,
          userSmartAccount: user1.address,
          referenceId: ethers.id("ref")
        })
      ).to.be.revertedWith("Pack does not exist");
    });

    it("Should reject zero amount deposits", async function () {
      const { packVault, user1 } = await loadFixture(setupPackFixture);

      await expect(
        packVault.connect(user1).deposit({
          packId: "bluechip",
          usdcAmount: 0,
          userSmartAccount: user1.address,
          referenceId: ethers.id("ref")
        })
      ).to.be.revertedWith("Amount must be > 0");
    });
  });

  describe("Pause/Unpause", function () {
    it("Should allow owner to pause", async function () {
      const { packVault, owner } = await loadFixture(deployPackVaultFixture);

      await expect(packVault.connect(owner).pause("Emergency"))
        .to.emit(packVault, "EmergencyPause");

      expect(await packVault.paused()).to.be.true;
    });

    it("Should prevent deposits when paused", async function () {
      const { packVault, usdc, user1, weth, wbtc } = await loadFixture(deployPackVaultFixture);

      // Create pack first
      await packVault.createPack("test", "Test", [
        { tokenAddress: await weth.getAddress(), weightBps: 5000, currentBalance: 0 },
        { tokenAddress: await wbtc.getAddress(), weightBps: 5000, currentBalance: 0 }
      ]);

      await packVault.pause("Test pause");

      await usdc.connect(user1).approve(await packVault.getAddress(), ethers.parseUnits("1000", 6));

      await expect(
        packVault.connect(user1).deposit({
          packId: "test",
          usdcAmount: ethers.parseUnits("1000", 6),
          userSmartAccount: user1.address,
          referenceId: ethers.id("ref")
        })
      ).to.be.revertedWithCustomError(packVault, "EnforcedPause");
    });

    it("Should allow owner to unpause", async function () {
      const { packVault } = await loadFixture(deployPackVaultFixture);

      await packVault.pause("Test");
      await expect(packVault.unpause())
        .to.emit(packVault, "EmergencyUnpause");

      expect(await packVault.paused()).to.be.false;
    });
  });

  describe("View Functions", function () {
    async function setupWithDepositsFixture() {
      const fixture = await setupPackFixture();
      const { packVault, usdc, user1, weth, wbtc, apt } = fixture;

      const allocations = [
        { tokenAddress: await weth.getAddress(), weightBps: 4000, currentBalance: 0 },
        { tokenAddress: await wbtc.getAddress(), weightBps: 3000, currentBalance: 0 },
        { tokenAddress: await apt.getAddress(), weightBps: 3000, currentBalance: 0 }
      ];

      await packVault.createPack("bluechip", "Bluechip Pack", allocations);

      // Make a deposit
      const depositAmount = ethers.parseUnits("5000", 6);
      await usdc.connect(user1).approve(await packVault.getAddress(), depositAmount);
      await packVault.connect(user1).deposit({
        packId: "bluechip",
        usdcAmount: depositAmount,
        userSmartAccount: user1.address,
        referenceId: ethers.id("ref")
      });

      return fixture;
    }

    it("Should return pack composition", async function () {
      const { packVault, weth, wbtc, apt } = await loadFixture(setupWithDepositsFixture);

      const composition = await packVault.getPackComposition("bluechip");
      expect(composition.length).to.equal(3);
      expect(composition[0].tokenAddress).to.equal(await weth.getAddress());
      expect(composition[0].weightBps).to.equal(4000);
    });

    it("Should return all pack IDs", async function () {
      const { packVault } = await loadFixture(setupWithDepositsFixture);

      const packs = await packVault.getAllPacks();
      expect(packs.length).to.equal(1);
      expect(packs[0]).to.equal("bluechip");
    });
  });
});
