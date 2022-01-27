// npx hardhat run scripts/deploySmartChefNFT_Roles.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);


const ownerAddress = `0xbafefe87d57d4c5187ed9bd5fab496b38abdd5ff`;
const BiswapNftAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`;
const smartChefAddress = `0x8F56515BF85dbF64DD3E282ab7f4D50Ff9791cC3`;
let biswapNft;

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;
    console.log(`nonce: ${+nonce}`);

    if(deployer.address.toLowerCase() !== ownerAddress.toLowerCase()){
        console.log(`Change deployer address. Current deployer: ${deployer.address}. Owner: ${ownerAddress}`);
        return;
    }

    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
    biswapNft = BiswapNFT.attach(BiswapNftAddress);

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
