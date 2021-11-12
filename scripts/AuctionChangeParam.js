//npx hardhat run scripts/deployMarketplace.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);

//BSW, WBNB, BUSD, USDT
const swapFeeRewardAddress = `0x04eFD76283A70334C72BB4015e90D034B9F3d245`;
const bswToken = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;
const usdtToken = `0x55d398326f99059ff775485246999027b3197955`;
const wbnbToken = `0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`;
const busdToken = `0xe9e7cea3dedca5984780bafc599bd69add087d56`;

const treasuryAddress = `0x863E9e0C64C18eF17DBb7a479499ea039c6b5AD3`;
const royaltyBREAddress = `0xAc6A4D92Ce734BFBE9C79210713A0E9753319b2B`;
//NFT tokens to whiteList
const BRE = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`;

//Auction deploy parameters
const extendEndTimestamp = 6*60*60;
const minAuctionDuration = 24*60*60;
const rateBase = 10000;
const bidderIncentiveRate = 500;
const bidIncrRate = 1000;
const prolongationTime = 60*10;

const auctionAddress = '0xE7D045e662BBBcC5c4AD3890f32211E0d36f4720';

let auction, tx;
async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;


    console.log(`Start change parameters on auction contract`);
    const Auction = await ethers.getContractFactory(`Auction`);
    auction = await Auction.attach(auctionAddress);

    console.log(`Update settings`)
    tx = await auction.updateSettings(
        extendEndTimestamp,
        prolongationTime,
        minAuctionDuration,
        rateBase,
        bidderIncentiveRate,
        bidIncrRate,
        treasuryAddress,
        swapFeeRewardAddress,
        {nonce: ++nonce, gasLimit: 3000000}
    )

    // console.log(`Pause auction`)
    // tx = await auction.pause({nonce: ++nonce, gasLimit: 3000000});
    // await tx.wait();
    //
    // console.log(`Unpause auction`)
    // tx = await auction.unpause({nonce: ++nonce, gasLimit: 3000000});
    // await tx.wait();

    // console.log(`Add tokens to Auction white list`);
    // tx = await auction.addWhiteListDealTokens([bswToken, usdtToken, wbnbToken, busdToken], {nonce: ++nonce, gasLimit: 3000000});
    // await tx.wait();
    //
    // console.log(`Add tokens to nftForAccrualRB on Auction`);
    // tx = await auction.addNftForAccrualRB(BRE, {nonce: ++nonce, gasLimit: 3000000});
    // await tx.wait();
    //
    //
    // console.log(`Add auction on swapFeeReward`);
    // const FeeReward = await ethers.getContractFactory(`SwapFeeRewardWithRB`);
    // const feeReward = await FeeReward.attach(swapFeeRewardAddress);
    // tx = await feeReward.setAuction(market.address, {nonce: ++nonce, gasLimit: 3000000});
    // await tx.wait();
    //
    // console.log(`Add royalty RBE token`)
    // tx = await auction.setRoyalty(BRE, royaltyBREAddress, 50, true, {nonce: ++nonce, gasLimit: 3000000})
    // await tx.wait();

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

