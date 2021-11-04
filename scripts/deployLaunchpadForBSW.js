const { ethers, network } = require(`hardhat`);
const hre = require("hardhat");

//Set parameters to launchpad
const treasuryAddress = `0x6332Da1565F0135E7b7Daa41C419106Af93274BA`;
//BSW token Address
const dealTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;
const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`;

let launchpad;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer address: ${ deployer.address}`);
  let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]);

  console.log(`Start deploy launchpad NFT`);
  const Launchpad = await ethers.getContractFactory('LaunchpadNftForBSW');
  launchpad = await Launchpad.deploy(biswapNFTAddress, dealTokenAddress, treasuryAddress, {nonce: nonce});
  await launchpad.deployTransaction.wait();
  console.log(`Launchpad NFT deployed to ${launchpad.address}`);



  console.log(`Setup roles`);
  let BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
  let biswapNft = await BiswapNFT.attach(biswapNFTAddress);

  const LAUNCHPAD_TOKEN_MINTER = await biswapNft.LAUNCHPAD_TOKEN_MINTER();
  let tx = await biswapNft.grantRole(LAUNCHPAD_TOKEN_MINTER, launchpad.address, {nonce: ++nonce, gasLimit: 3000000});
  await tx.wait();
  if(await biswapNft.hasRole(LAUNCHPAD_TOKEN_MINTER, launchpad.address)){
    console.log(`Role LAUNCHPAD_TOKEN_MINTER successfully added to address ${launchpad.address}`);
  } else{
    console.log(`WARNING!!! Role not added!!!`);
  }

  console.log(`Verify contract`);
  let res = await hre.run("verify:verify", {
    address: launchpad.address,
    constructorArguments: [biswapNFTAddress, dealTokenAddress, treasuryAddress]
  })
  console.log(res);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
