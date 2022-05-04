//npx hardhat run scripts/mintNFTTokens.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`
const to = `0xe843116517809C0d59c8a19dA4f7684f1d34433B`

//Task: BSW-1928
async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
    const biswapNft = await BiswapNFT.attach(biswapNFTAddress);

    console.log(`Mint tokens:`);
    for(let i = 0; i < 10; i++){
        await biswapNft.launchpadMint(to, 1, toBN(1,18), {nonce: ++nonce, gasLimit: 5e6});
        console.log(`   - Mint Robi token ${i+1}`);
    }

    console.log(`Done`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
