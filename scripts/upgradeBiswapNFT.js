const { ethers, network, hardhat, upgrades} = require(`hardhat`);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`;
const ownerAddress = `0xdb99fc9d9073feda71ef66200488b5fc652b1738`;
let biswapNft;


async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    if(accounts[0].address.toLowerCase() !== ownerAddress.toLowerCase()){
        console.log(`Change deployer address. Current deployer: ${accounts[0].address}. Owner: ${ownerAddress}`);
        return;
    }
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;
    console.log(`Start upgrade Biswap NFT contract`);
    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
    biswapNft = await upgrades.upgradeProxy(biswapNFTAddress, BiswapNFT,  {nonce: ++nonce, gasLimit: 5000000});
    await biswapNft.deployed();
    console.log(`Biswap NFT upgraded`);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
