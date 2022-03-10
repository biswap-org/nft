//npx hardhat run scripts/mintNFTTokens.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);
const {BigNumber} = require("ethers");

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`
const to = `0xe843116517809C0d59c8a19dA4f7684f1d34433B`
const level = 1
const rb = toBN(1,18);

let biswapNft

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    console.log(`mint NFT Tokens`);
    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
    biswapNft = await BiswapNFT.attach(biswapNFTAddress);
    for(let i = 0; i < 20; i++){
        await biswapNft.launchpadMint(to, level, rb, {nonce: ++nonce, gasLimit: 1e6});
        console.log(`token ${+i+1} minted`);
    }

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
