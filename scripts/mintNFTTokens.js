//npx hardhat run scripts/mintNFTTokens.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);
const {BigNumber} = require("ethers");

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`
const to = `0xF0aECBad150185Be71c6F3BEF40BB58F4CC5C8cf`


let biswapNft

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    console.log(`mint NFT Tokens`);
    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
    biswapNft = await BiswapNFT.attach(biswapNFTAddress);
    for(let i =0; i < 10; i++ ) await biswapNft.launchpadMint(to, 1, toBN(10,18), {nonce: ++nonce, gasLimit: 5e6});
    console.log(await biswapNft.balanceOf(to));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
      console.error(error);
      process.exit(1);
  });
