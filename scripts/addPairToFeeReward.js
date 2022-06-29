const { network, ethers } = require(`hardhat`);
const fs = require(`fs`);

const feeRewardAddress = `0x04eFD76283A70334C72BB4015e90D034B9F3d245`;
// const tokensList = `./tokens.json`;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer address: ${deployer.address}`);
  let nonce =
    (await network.provider.send(`eth_getTransactionCount`, [
      deployer.address,
      "latest",
    ])) - 1;

  let SwapFeeReward = await ethers.getContractFactory(`SwapFeeRewardWithRB`);
  let swapFeeReward = await SwapFeeReward.attach(feeRewardAddress);

  // console.log(`Add tokens to white list in swap fee reward`);
  // let tokens = fs.readFileSync(tokensList, "utf-8");
  // tokens = JSON.parse(tokens);
  //
  // for (const item of tokens) {
  //     console.log(`Try to add token ${item.name} address ${item.address} to contract`);
  //     console.log(`nonce: `, nonce);
  //     let tx = await swapFeeReward.addWhitelist(item.address, {nonce: ++nonce, gasLimit: 3000000});
  //     await tx.wait();
  // }
  //function setPair(uint256 _pid, uint256 _percentReward)
  //function setPairEnabled(uint256 _pid, bool _enabled)

  console.log(`Change fee return percent`);
  const pairPercent = [
    {pid: 0, percent: 23},
    {pid: 1, percent: 23},
    {pid: 2, percent: 23},
    {pid: 3, percent: 23},
    {pid: 4, percent: 23},
    {pid: 5, percent: 23},
    {pid: 6, percent: 23},
    {pid: 7, percent: 23},
    {pid: 8, percent: 20},
    {pid: 9, percent: 20},
    {pid: 10, percent: 20},
    {pid: 11, percent: 20},
    {pid: 12, percent: 20},
    {pid: 13, percent: 20},
    {pid: 14, percent: 0},
    {pid: 16, percent: 18},
    {pid: 18, percent: 70},
    {pid: 19, percent: 20},
    {pid: 20, percent: 20},
    {pid: 21, percent: 23},
    {pid: 22, percent: 18},
    {pid: 23, percent: 18},
    {pid: 24, percent: 18},
    {pid: 25, percent: 18},
    {pid: 26, percent: 18},
    {pid: 29, percent: 18},
    {pid: 32, percent: 18},
    {pid: 33, percent: 18},
    {pid: 34, percent: 18},
    {pid: 35, percent: 18},
    {pid: 36, percent: 18},
    {pid: 37, percent: 18},
    {pid: 38, percent: 18},
    {pid: 39, percent: 18},
    {pid: 40, percent: 18},
    {pid: 41, percent: 18},
    {pid: 42, percent: 18},
    {pid: 43, percent: 18},
    {pid: 44, percent: 18},
    {pid: 45, percent: 18},
    {pid: 46, percent: 18},
    {pid: 47, percent: 18},
    {pid: 48, percent: 18},
    {pid: 49, percent: 18},
    {pid: 50, percent: 18},
    {pid: 51, percent: 18},
    {pid: 52, percent: 18},
    {pid: 53, percent: 18},
    {pid: 54, percent: 18},
    {pid: 55, percent: 18},
    {pid: 56, percent: 18},
    {pid: 58, percent: 18},
    {pid: 59, percent: 18},
    {pid: 60, percent: 18},
    {pid: 62, percent: 18},
    {pid: 63, percent: 23},
    {pid: 64, percent: 18},
  ]
  for(const item of pairPercent) {
    await swapFeeReward.setPair(
      item.pid,
      item.percent,
      {nonce: ++nonce, gasLimit: 3000000}
    );

    console.log(`Pair pid: ${item.pid} percent changed to: ${item.percent}`);
  }

  // console.log(`Remove pairs from feeReward`);
  // let pidsToRemove = [15];
  // for (const item of pidsToRemove) {
  //   let tx = await swapFeeReward.setPairEnabled(item, false, {
  //     nonce: ++nonce,
  //     gasLimit: 3000000,
  //   });
  //
  // }

  // console.log(`Add pairs to swap fee reward`);
  // let pairs = [
  //   `0x284F871d6F2D4fE070F1E18c355eF2825e676AA2` // MANA - USDT
  // ];
  // for (const item of pairs) {
  //   await swapFeeReward.addPair(29, item, {
  //     nonce: ++nonce,
  //     gasLimit: 3000000,
  //   });
  //
  //   console.log(`Pair with address ${item} percent 29 added`);
  // }

  // let pairs = fs.readFileSync(`./Pair list.json`, "utf-8");
  // pairs = JSON.parse(pairs);
  //
  // for (const item of pairs) {
  //     if (item.enabled) {
  //         console.log(`Try add pair ${item.name.symbolA}/${item.name.symbolB} with address ${item.address} percent ${item.percent}`);
  //         console.log(`nonce: `, nonce);
  //         let tx = await swapFeeReward.addPair(item.percent, item.address, {nonce: ++nonce, gasLimit: 3000000});
  //         await tx.wait();
  //     }
  // }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
