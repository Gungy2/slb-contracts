import hardhat from "hardhat";
const ethers = hardhat.ethers;
const BigNumber = ethers.BigNumber;

const parseAmount = (amount, decimals) =>
  BigNumber.from(amount).mul(BigNumber.from(10).pow(decimals));

let deployer, acc1, acc2, acc3, acc4, slbToken, baseToken, book;

async function deployErc20(name, symbol) {
  const token = await (
    await (await ethers.getContractFactory("ERC20Test")).deploy(name, symbol)
  ).deployed();
  return token;
}

async function deploy() {
  baseToken = await deployErc20("baseToken", "baseToken");
  slbToken = await deployErc20("slbToken", "slbToken");
  book = await (
    await (
      await ethers.getContractFactory("OrderBook")
    ).deploy(slbToken.address, baseToken.address)
  ).deployed();
}

[deployer, acc1, acc2, acc3, acc4] = await ethers.getSigners();
await deploy();
await baseToken
  .connect(deployer)
  .transfer(await acc1.getAddress(), parseAmount(100000, 18));
await baseToken
  .connect(deployer)
  .transfer(await acc2.getAddress(), parseAmount(100000, 18));
await baseToken
  .connect(deployer)
  .transfer(await acc3.getAddress(), parseAmount(100000, 18));
await baseToken
  .connect(deployer)
  .transfer(await acc4.getAddress(), parseAmount(100000, 18));

await slbToken
  .connect(deployer)
  .transfer(await acc1.getAddress(), parseAmount(1000, 18));
await slbToken
  .connect(deployer)
  .transfer(await acc2.getAddress(), parseAmount(1000, 18));
await slbToken
  .connect(deployer)
  .transfer(await acc3.getAddress(), parseAmount(1000, 18));
await slbToken
  .connect(deployer)
  .transfer(await acc4.getAddress(), parseAmount(1000, 18));

await baseToken.connect(acc1).approve(book.address, parseAmount(100000, 18));
await baseToken.connect(acc2).approve(book.address, parseAmount(100000, 18));
await baseToken.connect(acc3).approve(book.address, parseAmount(100000, 18));
await baseToken.connect(acc4).approve(book.address, parseAmount(100000, 18));

await slbToken.connect(acc1).approve(book.address, parseAmount(1000, 18));
await slbToken.connect(acc2).approve(book.address, parseAmount(1000, 18));
await slbToken.connect(acc3).approve(book.address, parseAmount(1000, 18));
await slbToken.connect(acc4).approve(book.address, parseAmount(1000, 18));

console.log("HERE");
await book.connect(acc1).placeSellOrder(2, parseAmount(500, 18));
await book.connect(acc3).placeSellOrder(2, parseAmount(500, 18));
await book.connect(acc1).placeSellOrder(2, parseAmount(500, 18));
await book.connect(acc3).placeSellOrder(2, parseAmount(500, 18));
// await book.connect(acc1).placeSellOrder(2, parseAmount(500, 18));
// await book.connect(acc3).placeSellOrder(2, parseAmount(500, 18));
// await book.connect(acc1).placeSellOrder(2, parseAmount(500, 18));
await book.connect(acc2).placeBuyOrder(10, parseAmount(500, 18));
console.log("THERE");
