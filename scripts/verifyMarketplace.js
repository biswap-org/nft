const { ethers, network, hardhat, upgrades} = require(`hardhat`);
const {BigNumber} = require("ethers");
const hre = require("hardhat");

//BSW, WBNB, BUSD, USDT
const swapFeeRewardAddress = `0x04eFD76283A70334C72BB4015e90D034B9F3d245`;

const marketAddress = '';
const auctionAddress = ``;

const treasuryAddress = `0x6332Da1565F0135E7b7Daa41C419106Af93274BA`;

//Auction deploy parameters
const extendEndTimestamp = 60;
const minAuctionDuration = 60;
const rateBase = 10000;
const bidderIncentiveRate = 500;
const bidIncrRate = 1000;
const prolongationTime = 60*10;

async function main() {
    let accounts = await ethers.getSigners();

    console.log(`Verify market contract`);
    let res = await hre.run("verify:verify", {
        address: marketAddress,
        constructorArguments: [treasuryAddress, swapFeeRewardAddress]
    })
    console.log(res);

    console.log(`Verify auction contract`);
    res = await hre.run("verify:verify", {
        address: auctionAddress,
        constructorArguments: [
        extendEndTimestamp,
        prolongationTime,
        minAuctionDuration,
        rateBase,
        bidderIncentiveRate,
        bidIncrRate,
        treasuryAddress,
        swapFeeRewardAddress,
        ]
    })
    console.log(res);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

