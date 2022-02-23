const { ethers, network } = require(`hardhat`);

//Set parameters to launchpad
const treasuryAddress = `0x32386C7bc3cc8a465b131FAC0921a2088211a480`;
const dealTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;
const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`;
const startBlock = 15509000;
const autoBSWAddress = `0xa4b20183039b2F9881621C3A03732fBF0bfdff10`

let launchpad, biswapNft;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer address: ${ deployer.address}`);
  let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

  console.log(`Start deploy launchpad`);
  const Launchpad = await ethers.getContractFactory('RobiLaunchpad2102');
  launchpad = await Launchpad.deploy(biswapNFTAddress, dealTokenAddress, treasuryAddress, startBlock, autoBSWAddress, {nonce: ++nonce, gasLimit: 3000000});
  await launchpad.deployTransaction.wait();
  console.log(`Launchpad deployed to ${launchpad.address}`);


  console.log(`Setup roles`);
  let BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
  biswapNft = await BiswapNFT.attach(biswapNFTAddress);

  const LAUNCHPAD_TOKEN_MINTER = await biswapNft.LAUNCHPAD_TOKEN_MINTER();
  let tx = await biswapNft.grantRole(LAUNCHPAD_TOKEN_MINTER, launchpad.address, {nonce: ++nonce, gasLimit: 3000000});
  await tx.wait();
  if(await biswapNft.hasRole(LAUNCHPAD_TOKEN_MINTER, launchpad.address)){
    console.log(`Role LAUNCHPAD_TOKEN_MINTER successfully added to address ${launchpad.address}`);
  } else{
    console.log(`WARNING!!! Role not added!!!`);
  }

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
