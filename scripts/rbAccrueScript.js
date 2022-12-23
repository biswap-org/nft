//npx hardhat run scripts/mintNFTTokens.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`
const to = `0xF0aECBad150185Be71c6F3BEF40BB58F4CC5C8cf`


const RB_SETTER_ROLE = '0xc7c9819f33f023fb575ae9b63a0181942ca5956a309f3641e15d6dc199033e46'

let biswapNft


async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
    biswapNft = await BiswapNFT.attach(biswapNFTAddress);

    console.log(`Set RB_SETTER role`);
    await biswapNft.grantRole(RB_SETTER_ROLE, deployer.address, {nonce: ++nonce, gasLimit: 5e6});

    console.log(`Accrue RB to address`);
    await biswapNft.accrueRB(to, toBN(3, 18), {nonce: ++nonce, gasLimit: 5e6});

    console.log(`Done`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
