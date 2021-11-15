//npx hardhat run scripts/deployMarketplace.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);
const {BigNumber} = require("ethers");


const swapFeeRewardAddress = ``;
const nftStakingAddress = ``;
const swapFeeRewardMintingPerBlock = expandTo18Decimals(0);
const nftStakingMintingPerBlock = expandTo18Decimals(0);
const maxMint = expandTo18Decimals(0);
const bswToken = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;

function expandTo18Decimals(n) {
    return (new BigNumber.from(n)).mul((new BigNumber.from(10)).pow(18))
}

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]);

    const BswMint = await ethers.getContractFactory(`BSWMinting`);
    let bswMint = await BswMint.deploy(
        bswToken,
        swapFeeRewardAddress,
        nftStakingAddress,
        swapFeeRewardMintingPerBlock,
        nftStakingMintingPerBlock,
        maxMint,
        {nonce: nonce, gasLimit: 3000000}
    );
    await bswMint.deployTransaction.wait();
    console.log(`BSW Minting deployed to ${bswMint.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

