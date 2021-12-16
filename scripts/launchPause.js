const { ethers, network } = require(`hardhat`);
const hre = require("hardhat");

//Set parameters to launchpad
const launchpadAddress = `0x5ef6f1fd9341bd690d34e0b8298bf9885fc0824a`;
let launchpad;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer address: ${ deployer.address}`);
  let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]);

  console.log(`Start deploy launchpad Random`);
  const Launchpad = await ethers.getContractFactory('LaunchpadNftRandomNY');
  launchpad = await Launchpad.attach(launchpadAddress, {nonce: nonce, gasLimit: 3000000, gasPrice: 80000000000})
  let tx = await launchpad.pause();
  console.log(await tx.wait());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
