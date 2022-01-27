const { ethers, network, hardhat, upgrades} = require(`hardhat`);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`;
const ownerAddress = `0xbafefe87d57d4c5187ed9bd5fab496b38abdd5ff`;
let biswapNft;

const smartChefAddress = `0x8F56515BF85dbF64DD3E282ab7f4D50Ff9791cC3`;

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

    biswapNft = BiswapNFT.attach(biswapNFTAddress);
    console.log(`Setup roles`);
    const TOKEN_FREEZER = await biswapNft.TOKEN_FREEZER();
    const RB_SETTER_ROLE = await biswapNft.RB_SETTER_ROLE();
    await biswapNft.grantRole(TOKEN_FREEZER, smartChefAddress,  {nonce: ++nonce, gasLimit: 5000000});
    await biswapNft.grantRole(RB_SETTER_ROLE, smartChefAddress,  {nonce: ++nonce, gasLimit: 5000000});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
