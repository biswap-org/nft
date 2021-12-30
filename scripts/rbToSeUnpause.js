//npx hardhat run scripts/deployRBtoSE.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);
const {BigNumber} = require("ethers");

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const exchangerAddress = `0x45de5cBb576B04767e59049905662a6e6eC01496`;

async function main() {
  let accounts = await ethers.getSigners();
  console.log(`Deployer address: ${ accounts[0].address }`);
  let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;

  const Exchange = await ethers.getContractFactory(`RBToSEExchange`);
  const exchange = await Exchange.attach(exchangerAddress);
  await exchange.unpause({nonce: ++nonce, gasLimit: 3000000});

  console.log(`Exchanger unpaused`);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

