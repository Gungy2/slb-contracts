// Right click on the script name and hit "Run" to execute
import { expect } from "chai";
import hardhat from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
const ethers = hardhat.ethers;

describe("SLB_Bond contract", function () {
  let owner;
  let addr1;
  let addr2;
  let addr3;
  let addr4;
  let addrs;

  let bond;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4, ...addrs] = await ethers.getSigners();

    // Deploy Contract
    const SLB_Bond = await ethers.getContractFactory("SLB_Bond");
    bond = await SLB_Bond.deploy();
  });

  describe("SLB_Bond tests", function () {
    it("test initial status", async function () {
      expect((await bond.connect(owner).status()).toString()).to.equal("0");
    });

    it("test set roles", async function () {
      const roles = await bond
        .connect(owner)
        .setRoles(
          "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2",
          "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
        );
      await roles.wait();
      expect((await bond.connect(owner).issuer()).toString()).to.equal(
        "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2"
      );
      expect((await bond.connect(owner).verifier()).toString()).to.equal(
        "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
      );
    });

    it("test set and mint bond", async function () {
      const roles = await bond
        .connect(owner)
        .setRoles(addr1.getAddress(), addr2.getAddress());
      let nowUnix = await time.latest();
      const newBond = await bond
        .connect(addr1)
        .setBond(
          "Bond 1, KPI: Greenhouse gas emissions",
          [1, 0, 0],
          100,
          1,
          10,
          5,
          100,
          nowUnix + 10000,
          nowUnix + 20000,
          nowUnix + 30000
        );
      await newBond.wait();
      const buyBond = await bond.connect(addr3).mintBond(20);
      await buyBond.wait();
      expect((await bond.connect(addr3).bondsForSale()).toString()).to.equal(
        "80"
      );
    });

    it("test set bond active", async function () {
      const roles = await bond
        .connect(owner)
        .setRoles(addr1.getAddress(), addr2.getAddress());
      let nowUnix = await time.latest();
      const newBond = await bond
        .connect(addr1)
        .setBond(
          "Bond 1, KPI: Greenhouse gas emissions",
          [1, 0, 0],
          100,
          1,
          10,
          5,
          100,
          nowUnix + 100,
          nowUnix + 20000,
          nowUnix + 30000
        );
      await newBond.wait();
      expect((await bond.connect(addr1).status()).toString()).to.equal("1");
      await time.increase(105);
      const bondActive = await bond.connect(addr1).setBondActive();
      await bondActive.wait();
      expect((await bond.connect(addr1).status()).toString()).to.equal("2");
    });

    it("test fund bond and withdraw funds", async function () {
      const roles = await bond
        .connect(owner)
        .setRoles(addr1.getAddress(), addr2.getAddress());
      const addFunds = await bond.connect(addr1).fundBond({
        value: ethers.utils.parseUnits("2", "wei"),
      });
      await addFunds.wait();
      expect((await bond.connect(owner).getBalance()).toString()).to.equal("2");
      const withdrawFunds = await bond
        .connect(addr1)
        .withdrawMoney(ethers.utils.parseUnits("1", "wei"));
      await withdrawFunds.wait();
      expect((await bond.connect(owner).getBalance()).toString()).to.equal("1");
    });

    it("test report and verify impact", async function () {
      const roles = await bond
        .connect(owner)
        .setRoles(addr1.getAddress(), addr2.getAddress());
      let nowUnix = await time.latest();
      const newBond = await bond
        .connect(addr1)
        .setBond(
          "Bond 1, KPI: Greenhouse gas emissions",
          [1, 0, 0],
          100,
          1,
          10,
          5,
          100,
          nowUnix + 10,
          nowUnix + 11,
          nowUnix + 12
        );

      await newBond.wait();
      await time.increase(10);
      const bondActive = await bond.connect(addr1).setBondActive();

      const deviceRegister = await bond.connect(addr1).registerDevice("123");

      const deviceHash = await bond
        .connect(addr1)
        .hash("123", addr1.getAddress(), 1, 2, 3);

      expect(
        await bond.connect(addr1).checkDevice("123", deviceHash, 1, 2, 3)
      ).to.equal(true);

      const bondReport = await bond
        .connect(addr1)
        .reportImpact(1, 2, 3, "123", deviceHash);
      await bondReport.wait();

      expect((await bond.connect(addr1).currentPeriod()).toString()).to.equal(
        "1"
      );
      expect((await bond.connect(addr1).isReported()).toString()).to.equal(
        "true"
      );

      const bondVerify = await bond.connect(addr2).verifyImpact(true);
      await bondVerify.wait();
      expect((await bond.connect(addr2).isVerified()).toString()).to.equal(
        "true"
      );
    });

    it("test regulator (transfer ownership, freeze and unfreeze bond)", async function () {
      const roles = await bond
        .connect(owner)
        .setRoles(addr1.getAddress(), addr2.getAddress());
      const transferBond = await bond
        .connect(owner)
        .transferOwnership(addr4.getAddress());
      const freeze = await bond.connect(addr4).freezeBond();
      await freeze.wait();

      expect((await bond.connect(addr4).paused()).toString()).to.equal("true");

      const unfreeze = await bond.connect(addr4).unfreezeBond();
      await unfreeze.wait();

      expect((await bond.connect(addr4).paused()).toString()).to.equal("false");
    });

    it("test initial status", async function () {
      expect((await bond.connect(owner).status()).toString()).to.equal("0");
    });
  });

  describe("SLB_Bond ERC20", function () {
    it("can get transferred ", async function () {
      const roles = await bond
        .connect(owner)
        .setRoles(addr1.getAddress(), addr2.getAddress());
      const addFunds = await bond.connect(addr1).fundBond({
        value: ethers.utils.parseUnits("200", "wei"),
      });
      await addFunds.wait();

      let nowUnix = await time.latest();

      const newBond = await bond
        .connect(addr1)
        .setBond(
          "Bond 1, KPI: Greenhouse gas emissions",
          [1, 0, 0],
          100,
          1,
          10,
          5,
          100,
          nowUnix + 10,
          nowUnix + 20,
          nowUnix + 1000
        );
      await newBond.wait();

      const buyBond = await bond.connect(addr3).mintBond(20);
      await buyBond.wait();
      expect(await bond.connect(addr3).balanceOf(addr3.getAddress())).to.equal(
        20
      );

      const approveBond = await bond
        .connect(addr3)
        .approve(addr4.getAddress(), 10);
      await approveBond.wait();
      expect(
        await bond
          .connect(addr3)
          .allowance(addr3.getAddress(), addr4.getAddress())
      ).to.equal(10);

      const transferBond = await bond
        .connect(addr4)
        .transferFrom(addr3.getAddress(), addr4.getAddress(), 5);
      await transferBond.wait();
      expect(
        await bond
          .connect(addr3)
          .allowance(addr3.getAddress(), addr4.getAddress())
      ).to.equal(5);
      expect(await bond.connect(addr3).balanceOf(addr3.getAddress())).to.equal(
        15
      );
      expect(await bond.connect(addr3).balanceOf(addr4.getAddress())).to.equal(
        5
      );

      await time.increase(11);
      const bondActive = await bond.connect(addr1).setBondActive();
      await bondActive.wait();

      await bond.connect(addr1).registerDevice("123");

      const deviceHash = await bond
        .connect(addr1)
        .hash("123", addr1.getAddress(), 1, 2, 3);

      await time.increase(5);
      const bondReport = await bond
        .connect(addr1)
        .reportImpact(1, 2, 3, "123", deviceHash);
      await bondReport.wait();

      const bondVerify = await bond.connect(addr2).verifyImpact(true);
      await bondVerify.wait();

      await expect(
        bond.connect(addr3).transfer(addr4.getAddress(), 5)
      ).to.be.revertedWith(
        "Cannot transfer bonds from an account with unclaimed funds."
      );

      const claimCoupon = await bond.connect(addr3).claimCoupon(1);
      await claimCoupon.wait();

      const transferBond2 = await bond
        .connect(addr4)
        .transferFrom(addr3.getAddress(), addr4.getAddress(), 5);
      await transferBond2.wait();
      expect(await bond.connect(addr3).balanceOf(addr4.getAddress())).to.equal(
        10
      );
    });
  });
});
