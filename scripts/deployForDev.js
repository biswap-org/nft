//npx hardhat run scripts/deployForDev.js --network testnetBSC
const { ethers, network, upgrades } = require(`hardhat`);
const {BigNumber} = require("ethers");
const fs = require(`fs`)
const hre = require("hardhat");
/*
* 1. Set Market contract on SwapFeeReward
* 2. Set Auction contract on SwapFeeReward
* 3. Add Swap fee reward contract to Router contract
* 4. Add reward tokens to SmartChef contract
* 5.
* */

//Set parameters to deploy BiswapNFT
const baseURI = `http://dev.bsadm.me/back/nft/metadata/`;
const initialRB = expandTo18Decimals(1);
const burnRBPeriod = 10;

//Set parameters to deploy Swap fee reward
const factory = `0x858e3312ed3a876947ea49d572a7c42de08af7ee`;
const router = `0x3a6d8ca21d1cf76f653a67577fa0d27453350dd8`;
const INIT_CODE_HASH = `0xfea293c909d87cd4153593f077b76bb7e94340200f4ee84211ae8e4f9bd7ffdf`;
const oracleAddress = `0x2f48cde4cfd0fb4f5c873291d5cf2dc9e61f2db0`;
const bswTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;
const usdtTokenAddress = `0x55d398326f99059fF775485246999027B3197955`;

//Set parameters to deploy SmartChef NFT
const wbnbAddress = `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c`;

//Set parameters to launchpad
const treasuryAddressLaunchpad = `0x6332Da1565F0135E7b7Daa41C419106Af93274BA`

function expandTo18Decimals(n) {
    return (new BigNumber.from(n)).mul((new BigNumber.from(10)).pow(18))
}

let biswapNft, swapFeeReward, smartChef, launchpad;

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]);
    console.log(`Start deploying Biswap NFT contract`);
    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
    biswapNft = await upgrades.deployProxy(BiswapNFT, [baseURI, initialRB, burnRBPeriod], {nonce: nonce});
    await biswapNft.deployTransaction.wait();
    console.log(`Biswap NFT deployed to ${biswapNft.address}`);

    console.log(`Start deploying SmartChef NFT`);
    const SmartChef = await ethers.getContractFactory(`SmartChefNFT`);
    smartChef = await SmartChef.deploy(biswapNft.address, {nonce: ++nonce});
    await smartChef.deployTransaction.wait();
    console.log(`SmartChefNFT deployed to ${smartChef.address}`);

    console.log(`Start deploy launchpad NFT`);
    const Launchpad = await ethers.getContractFactory('LaunchpadNFT');
    launchpad = await Launchpad.deploy(biswapNft.address, oracleAddress, wbnbAddress, usdtTokenAddress, {nonce: ++nonce});
    await launchpad.deployTransaction.wait();
    console.log(`Launchpad NFT deployed to ${launchpad.address}`);
    console.log(`Set white list deal token USDT`);
    let tx = await launchpad.setWhitelistDealToken(usdtTokenAddress, {nonce: ++nonce, gasLimit: 3000000});
    await tx.wait();
    console.log(`set treasury address to launchpad`)
    tx = await launchpad.setTreasuryAddress(treasuryAddressLaunchpad, {nonce: ++nonce, gasLimit: 3000000});
    await tx.wait();

    console.log(`Start deploying SwapFeeReward contract`);
    const SwapFeeReward = await ethers.getContractFactory(`SwapFeeRewardWithRB`);
    swapFeeReward = await SwapFeeReward.deploy(factory, router, INIT_CODE_HASH, bswTokenAddress, oracleAddress, biswapNft.address, bswTokenAddress, usdtTokenAddress, {nonce: ++nonce});
    await swapFeeReward.deployTransaction.wait();
    console.log(`SwapFeeReward contract deployed to ${swapFeeReward.address}`);


    console.log(`Set roles`);
    const RB_SETTER = await biswapNft.RB_SETTER_ROLE();
    const TOKEN_FREEZER = await biswapNft.TOKEN_FREEZER();
    const LAUNCHPAD_TOKEN_MINTER = await biswapNft.LAUNCHPAD_TOKEN_MINTER();
    await biswapNft.grantRole(RB_SETTER, swapFeeReward.address, {nonce: ++nonce, gasLimit: 3000000});
    await biswapNft.grantRole(TOKEN_FREEZER, smartChef.address, {nonce: ++nonce, gasLimit: 3000000});
    await biswapNft.grantRole(LAUNCHPAD_TOKEN_MINTER, launchpad.address, {nonce: ++nonce, gasLimit: 3000000});

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
