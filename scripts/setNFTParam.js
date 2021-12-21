//npx hardhat run scripts/deployMarketplace.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);

const royaltyBusAddress = `0xcD3CD3f8764aA2FD474421c8c81514A50883678a`;
const royaltyPlayerAddress = `0x8D318c35B14D168ea69b76FE6Ed8b77A24C86FA4`;

//NFT tokens to whiteList
const busNFT = `0x6d57712416eD4890e114A37E2D84AB8f9CEe4752`;
const playerNFT = `0xb00ED7E3671Af2675c551a1C26Ffdcc5b425359b`;

const auctionAddress = '0xE7D045e662BBBcC5c4AD3890f32211E0d36f4720';
const marketAddress = '0x23567C7299702018B133ad63cE28685788ff3f67';

let auction, market, tx;
async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;

    const Auction = await ethers.getContractFactory(`Auction`);
    auction = await Auction.attach(auctionAddress);
    const Market = await ethers.getContractFactory(`Market`);
    market = await Market.attach(marketAddress);

    console.log(`Add NFT tokens for accrual RB on Auction`);
    await auction.addNftForAccrualRB(busNFT, {nonce: ++nonce, gasLimit: 3000000});
    await auction.addNftForAccrualRB(playerNFT, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add NFT tokens for accrual RB on Market`);
    await market.addNftForAccrualRB(busNFT, {nonce: ++nonce, gasLimit: 3000000});
    await market.addNftForAccrualRB(playerNFT, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add royalty to auction`)
    await auction.setRoyalty(busNFT, royaltyBusAddress, 100, true, {nonce: ++nonce, gasLimit: 3000000})
    await auction.setRoyalty(playerNFT, royaltyPlayerAddress, 100, true, {nonce: ++nonce, gasLimit: 3000000})

    console.log(`Add royalty to market`)
    await market.setRoyalty(busNFT, royaltyBusAddress, 100, true, {nonce: ++nonce, gasLimit: 3000000})
    await market.setRoyalty(playerNFT, royaltyPlayerAddress, 100, true, {nonce: ++nonce, gasLimit: 3000000})

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

