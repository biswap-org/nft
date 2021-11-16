//npx hardhat run scripts/deployMarketplace.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);
const {BigNumber} = require("ethers");


const swapFeeRewardAddress = `0xFaA9d8BB498ce62c1568170bA706cFeBB9B9ec19`;
const nftStakingAddress = `0x586f7Aac5A3B111d6Acf59f1B0aCa2d72C91223d`;
const swapFeeRewardMintingPerBlock = '1041666666666666666';
const nftStakingMintingPerBlock = '198412698400000000';
const maxMint = expandTo18Decimals(60000000);
const bswToken = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;

function expandTo18Decimals(n) {
    return (new BigNumber.from(n)).mul((new BigNumber.from(10)).pow(18))
}

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address }`);
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

