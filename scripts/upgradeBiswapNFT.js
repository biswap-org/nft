const { ethers, network, hardhat, upgrades} = require(`hardhat`);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`;
const ownerAddress = `0xbafefe87d57d4c5187ed9bd5fab496b38abdd5ff`;
let biswapNft;

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    if(accounts[0].address !== ownerAddress){
        console.log(`Change deployer address. Current deployer: ${accounts[0].address}. Owner: ${ownerAddress}`);
        return;
    }
    console.log(`Start upgrade Biswap NFT contract`);
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
