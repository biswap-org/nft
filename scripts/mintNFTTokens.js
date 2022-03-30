//npx hardhat run scripts/mintNFTTokens.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`
const to = `0xe4a922f8fDAb0Fba636766c0C8C3fD864845163f`


let biswapNft
//Task: BSW-1731
async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    console.log(`mint NFT Tokens`);
    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
    biswapNft = await BiswapNFT.attach(biswapNFTAddress);
    await biswapNft.launchpadMint(to, 2, toBN(66,18), {nonce: ++nonce, gasLimit: 5e6});
    await biswapNft.launchpadMint(to, 1, toBN(8,18), {nonce: ++nonce, gasLimit: 5e6});
    await biswapNft.launchpadMint(to, 1, toBN(7,18), {nonce: ++nonce, gasLimit: 5e6});
    await biswapNft.launchpadMint(to, 1, toBN(6,18), {nonce: ++nonce, gasLimit: 5e6});
    await biswapNft.launchpadMint(to, 1, toBN(5,18), {nonce: ++nonce, gasLimit: 5e6});
    await biswapNft.launchpadMint(to, 1, toBN(4,18), {nonce: ++nonce, gasLimit: 5e6});
    await biswapNft.launchpadMint(to, 1, toBN(4,18), {nonce: ++nonce, gasLimit: 5e6});
    await biswapNft.launchpadMint(to, 1, toBN(4,18), {nonce: ++nonce, gasLimit: 5e6});
    await biswapNft.launchpadMint(to, 1, toBN(4,18), {nonce: ++nonce, gasLimit: 5e6});
    await biswapNft.launchpadMint(to, 1, toBN(4,18), {nonce: ++nonce, gasLimit: 5e6});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
