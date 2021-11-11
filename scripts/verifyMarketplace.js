const { ethers, network, hardhat, upgrades} = require(`hardhat`);
const {BigNumber} = require("ethers");
const hre = require("hardhat");

//BSW, WBNB, BUSD, USDT
const swapFeeRewardAddress = `0x04eFD76283A70334C72BB4015e90D034B9F3d245`;

const marketAddress = `0x2b6bF07219769AFb56BeAa3b88fea5C128eAFb79`;
const auctionAddress = `0x349Ea9e8b8f039A944aa120341E8F9eDfED93785`;

//Auction deploy parameters
const extendEndTimestamp = 60;
const minAuctionDuration = 60;
const rateBase = 10000;
const bidderIncentiveRate = 1000;
const bidIncrRate = 1000;


async function main() {
    let accounts = await ethers.getSigners();

    console.log(`Verify market contract`);
    let res = await hre.run("verify:verify", {
        address: marketAddress,
        constructorArguments: [accounts[0].address, swapFeeRewardAddress]
    })
    console.log(res);

    console.log(`Verify auction contract`);
    res = await hre.run("verify:verify", {
        address: auctionAddress,
        constructorArguments: [
            extendEndTimestamp,
            minAuctionDuration,
            rateBase,
            bidderIncentiveRate,
            bidIncrRate,
            accounts[0].address,
            swapFeeRewardAddress
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

