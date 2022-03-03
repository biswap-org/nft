//npx hardhat run scripts/addNewCollections1502.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);

//NFT tokens to whiteList

// deploy parameters
const auctionAddress = '0xE7D045e662BBBcC5c4AD3890f32211E0d36f4720';
const marketAddress = `0x23567C7299702018B133ad63cE28685788ff3f67`;
const ownerAddress = `0xbafefe87d57d4c5187ed9bd5fab496b38abdd5ff`;


//Tokens addresses
const piratesAddress = `0xfa7eD23E2a5cd9C7B752288FbbA627CEcECCA928`;
const shipsAddress = `0x3Df7076b8beb46Dc26017e1D46E0e7046A1Ca41F`;
const ARTAddress = `0xbd74bf73780096E12B8d9Df415d7Fe7dB55822eC`;
const SandboxAddress = `0xF261E1b48E57bB6b3345D0De11B86d390267387a`;


let auction, market;
async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;

    if(accounts[0].address.toLowerCase() !== ownerAddress.toLowerCase()){
        console.log(`Change deployer address. Current deployer: ${accounts[0].address}. Owner: ${ownerAddress}`);
        return;
    }

    const Auction = await ethers.getContractFactory(`Auction`);
    auction = await Auction.attach(auctionAddress);
    const Market = await ethers.getContractFactory(`Market`);
    market = await Market.attach(marketAddress);


    console.log(`Add Pirates to nftForAccrualRB on Auction`);
    await auction.addNftForAccrualRB(piratesAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add Pirates to nftForAccrualRB on Market`);
    await market.addNftForAccrualRB(piratesAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add ships to nftForAccrualRB on Auction`);
    await auction.addNftForAccrualRB(shipsAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add ships to nftForAccrualRB on Market`);
    await market.addNftForAccrualRB(shipsAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add ART to nftForAccrualRB on Auction`);
    await auction.addNftForAccrualRB(ARTAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add ART to nftForAccrualRB on Market`);
    await market.addNftForAccrualRB(ARTAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add Sandbox to nftForAccrualRB on Auction`);
    await auction.addNftForAccrualRB(SandboxAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Add Sandbox to nftForAccrualRB on Market`);
    await market.addNftForAccrualRB(SandboxAddress, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Done`)

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

