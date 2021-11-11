//npx hardhat run scripts/deployMarketplace.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);

//BSW, WBNB, BUSD, USDT
const swapFeeRewardAddress = `0x04eFD76283A70334C72BB4015e90D034B9F3d245`;
const bswToken = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;
const usdtToken = `0x55d398326f99059ff775485246999027b3197955`;
const wbnbToken = `0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`;
const busdToken = `0xe9e7cea3dedca5984780bafc599bd69add087d56`;

//NFT tokens to whiteList
const BRE = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`;

//Auction deploy parameters
const extendEndTimestamp = 60;
const minAuctionDuration = 60;
const rateBase = 10000;
const bidderIncentiveRate = 1000;
const bidIncrRate = 1000;

let market, auction, tx;
async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]);

    //Market ----------------------------------------------------------------------------------------------------------

    console.log(`Start deploying Market contract`);
    const Market = await ethers.getContractFactory(`Market`);
    market = await Market.deploy(accounts[0].address, swapFeeRewardAddress, {nonce: nonce});
    await market.deployTransaction.wait();
    console.log(`Market contract was deployed to ${market.address}`);

    console.log(`Add deal tokens`);
    tx = await market.addWhiteListDealTokens([bswToken, usdtToken, wbnbToken, busdToken], {nonce: ++nonce, gasLimit: 3000000});
    await tx.wait();

    // console.log(`add marketplace to swapFeeReward`);
    // const FeeReward = await ethers.getContractFactory(`SwapFeeRewardWithRB`);
    // const feeReward = await FeeReward.attach(swapFeeRewardAddress);
    // tx = await feeReward.setMarket(market.address, {nonce: ++nonce, gasLimit: 3000000});
    // await tx.wait();

    console.log(`Add tokens to nftForAccrualRB on Market`);
    tx = await market.addNftForAccrualRB(BRE, {nonce: ++nonce, gasLimit: 3000000});
    await tx.wait();

    //Auction ---------------------------------------------------------------------------------------------------------

    console.log(`Start deploy auction contract`);
    const Auction = await ethers.getContractFactory(`Auction`);
    auction = await Auction.deploy(
        extendEndTimestamp,
        minAuctionDuration,
        rateBase,
        bidderIncentiveRate,
        bidIncrRate,
        accounts[0].address,
        swapFeeRewardAddress,
        {nonce: ++nonce}
    );
    await auction.deployTransaction.wait();
    console.log(`Auction deploy on ${auction.address}`);

    console.log(`Add tokens to white list`);
    tx = await auction.addWhiteListDealTokens([bswToken, usdtToken, wbnbToken, busdToken], {nonce: ++nonce, gasLimit: 3000000});
    await tx.wait();

    // console.log(`Add auction on swapFeeReward`);
    // tx = await feeReward.setAuction(market.address, {nonce: ++nonce, gasLimit: 3000000});
    // await tx.wait();

    console.log(`Add tokens to nftForAccrualRB on Auction`);
    tx = await auction.addNftForAccrualRB(BRE, {nonce: ++nonce, gasLimit: 3000000});
    await tx.wait();

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

