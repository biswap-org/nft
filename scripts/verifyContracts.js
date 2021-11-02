const hre = require('hardhat');

const biswapNFTAddress = ``;
const swapFeeRewardNFTAddress = ``;
const launchpadAddress = '';
const smartChefAddress = '';


//Set parameters to deploy Swap fee reward
const factory = `0x858e3312ed3a876947ea49d572a7c42de08af7ee`;
const router = `0x3a6d8ca21d1cf76f653a67577fa0d27453350dd8`;
const INIT_CODE_HASH = `0xfea293c909d87cd4153593f077b76bb7e94340200f4ee84211ae8e4f9bd7ffdf`;
const oracleAddress = `0x2f48cde4cfd0fb4f5c873291d5cf2dc9e61f2db0`;
const bswTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;
const usdtTokenAddress = `0x55d398326f99059fF775485246999027B3197955`;

//Set parameters to deploy SmartChef NFT
const wbnbAddress = `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c`;


async function main() {

    console.log(`Verify Biswap NFT contract`);

    let res = await hre.run("verify:verify", {
        address: biswapNFTAddress,
        constructorArguments: []
    })
    console.log(res);

    console.log(`Verify contract smartChef`);
    res = await hre.run("verify:verify", {
        address: smartChefAddress,
        constructorArguments: [biswapNFTAddress]
    })
    console.log(res);

    console.log(`Verify contract launchpad`);
    res = await hre.run("verify:verify", {
        address: launchpadAddress,
        constructorArguments: [biswapNFTAddress, oracleAddress, wbnbAddress, usdtTokenAddress]
    })
    console.log(res);

    console.log(`Verify contract SwapFeeReward`);
    res = await hre.run("verify:verify", {
        address: swapFeeRewardNFTAddress,
        constructorArguments: [factory, router, INIT_CODE_HASH, bswTokenAddress, oracleAddress, biswapNFTAddress, bswTokenAddress, usdtTokenAddress]
    })
    console.log(res);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });