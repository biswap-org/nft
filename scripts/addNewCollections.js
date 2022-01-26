//npx hardhat run scripts/addNewCollections.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);

//NFT tokens to whiteList

// deploy parameters
const auctionAddress = '0xE7D045e662BBBcC5c4AD3890f32211E0d36f4720';
const marketAddress = `0x23567C7299702018B133ad63cE28685788ff3f67`;
const ownerAddress = `0xbafefe87d57d4c5187ed9bd5fab496b38abdd5ff`;


//Collections parameters
// Treasury
// For BornBadBoys :
//     0x952B8A6AC7957B769C6cAD934b128f2d27368565
//
// For BornBadGirls :
//     0x0Cb4a3C664556866B3fdeAD2A18047Af0EC3DcaB
const BornBadBoysTreasuryAddress = `0x952B8A6AC7957B769C6cAD934b128f2d27368565`;
const BornBadGirlsTreasuryAddress = `0x0Cb4a3C664556866B3fdeAD2A18047Af0EC3DcaB`;

//Tokens addresses
//BornBadBoys
// 0x44d85770aEa263F9463418708125Cd95e308299B
//
// BornBadGirls
// 0x3da8410e6EF658c06E277a2769816688c37496CF
const BornBadBoysAddress = `0x44d85770aEa263F9463418708125Cd95e308299B`;
const BornBadGirlsAddress = `0x3da8410e6EF658c06E277a2769816688c37496CF`;



let auction, market;
async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;

    if(accounts[0].address !== ownerAddress){
        console.log(`Change deployer address. Current deployer: ${accounts[0].address}. Owner: ${ownerAddress}`);
        return;
    }

    const Auction = await ethers.getContractFactory(`Auction`);
    auction = await Auction.attach(auctionAddress);
    const Market = await ethers.getContractFactory(`Market`);
    market = await Market.attach(marketAddress);


    console.log(`Add BornBadBoys to nftForAccrualRB on Auction`);
    await auction.addNftForAccrualRB(BornBadBoysAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add BornBadGirls to nftForAccrualRB on Auction`);
    await auction.addNftForAccrualRB(BornBadGirlsAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add BornBadBoys to nftForAccrualRB on Market`);
    await market.addNftForAccrualRB(BornBadBoysAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add BornBadGirls to nftForAccrualRB on Market`);
    await market.addNftForAccrualRB(BornBadGirlsAddress, {nonce: ++nonce, gasLimit: 3000000});


    console.log(`Add BornBadBoys treasury on auction`)
    await auction.setRoyalty(BornBadBoysAddress, BornBadBoysTreasuryAddress, 100, true, {nonce: ++nonce, gasLimit: 3000000})

    console.log(`Add BornBadGirls treasury on auction`)
    await auction.setRoyalty(BornBadGirlsAddress, BornBadGirlsTreasuryAddress, 100, true, {nonce: ++nonce, gasLimit: 3000000})

    console.log(`Add BornBadBoys treasury on market`)
    await market.setRoyalty(BornBadBoysAddress, BornBadBoysTreasuryAddress, 100, true, {nonce: ++nonce, gasLimit: 3000000})

    console.log(`Add BornBadGirls treasury on market`)
    await market.setRoyalty(BornBadGirlsAddress, BornBadGirlsTreasuryAddress, 100, true, {nonce: ++nonce, gasLimit: 3000000})

    console.log(`Done`)

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

