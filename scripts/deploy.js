// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
import hardhat from "hardhat";
const ethers = hardhat.ethers;

async function main() {
  // Deploy Contract
  const [owner, addr1, addr2, addr3, addr4, ...addrs] = await ethers.getSigners();

  const SLB_Bond = await ethers.getContractFactory("SLB_Bond");
  const bond = await SLB_Bond.deploy();
  console.log(
    await bond.connect(owner).balanceOf("0x9e5Decd7DE5e12336ef6E10A6d0C28d1938Df8E1")
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
