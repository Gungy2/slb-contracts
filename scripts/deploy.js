// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
import hardhat from "hardhat";
const ethers = hardhat.ethers;

async function main() {
  const myAddress =  process.env.ADDRESS ?? "0x99D95fD49544De3BE43Bf905a2fc47006C0A4afC";

  // Deploy Contract
  const [owner, addr1, addr2, addr3] = await ethers.getSigners();

  await owner.sendTransaction({
    to: myAddress,
    value: ethers.utils.parseEther("1.0"), // Sends exactly 1.0 ether
  });

  const SLB_Bond = await ethers.getContractFactory("SLB_Bond");
  const bond = await SLB_Bond.deploy();

  const roles = await bond
    .connect(owner)
    .setRoles(addr1.getAddress(), addr2.getAddress());
  const addFunds = await bond.connect(addr1).fundBond({
    value: ethers.utils.parseUnits("200", "wei"),
  });
  await addFunds.wait();
  const nowUnix = Math.floor(Date.now() / 1000);

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
      nowUnix + 50,
      nowUnix + 100,
      nowUnix + 150
    );
  await newBond.wait();

  const buyBond = await bond.connect(addr3).mintBond(20);
  await buyBond.wait();

  await bond.connect(addr3).transfer(myAddress, 5);
  console.log(`Bond address: ${bond.address}`);

  const stableCoin = await ethers.getContractFactory("ERC20Test");
  const coin = await stableCoin.deploy("StableCoin", "STC");
  await coin.connect(owner).transfer(myAddress, 10 ** 10);
  console.log(coin.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
