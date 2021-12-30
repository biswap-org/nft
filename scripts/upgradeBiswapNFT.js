const { ethers, network, hardhat, upgrades} = require(`hardhat`);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`;
let biswapNft;

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    console.log(`Start deploying upgrade Biswap NFT contract`);
    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
    biswapNft = await upgrades.upgradeProxy(biswapNFTAddress, BiswapNFT);
    await biswapNft.deployed();
    console.log(`Biswap NFT upgraded`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
