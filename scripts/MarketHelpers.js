const ethers = require(`ethers`);
const {artifacts} = require("hardhat");
const { mnemonic, PK_NFT } = require('../secrets.json');
const {BigNumber} = require("ethers");

//Addresses
/* Test NFT tokens
* 0xc014b45d680b5a4bf51ccda778a68d5251c14b5e ID5226
* 0xdf7952b35f24acf7fc0487d01c8d5690a60dba07 ID25101
* 0x9f0225d5c92b9cee4024f6406c4f13e546fd91a8 ID 10151
* 0x85F0e02cb992aa1F9F47112F815F519EF1A59E2D ID 10000773814
* 0xD4220B0B196824C2F548a34C47D81737b0F6B5D6 ID 2827

 */

const marketAddress = `0x312De427721B60FcB54d756f60aFaBEa156A6931`;
const auctionAddress = `0x7B45aF17b8FFE2217f2F08BB6870045421cEe5bb`;
const dealTokenAddress = '0x172522f44ead163718d63e5e9181220d1c1d8638';
const bswTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;

const biswapNFTArtifact = artifacts.readArtifactSync(`BiswapNFT`);
const marketArtifact = artifacts.readArtifactSync(`Market`);
const dealTokenArtifact = artifacts.readArtifactSync(`Token`);
const auctionArtifact = artifacts.readArtifactSync(`Auction`);


const provider = new ethers.providers.StaticJsonRpcProvider(
    `https://bsc-dataseed.binance.org/`,
    {
        chainId: 56,
        name: `BSC`
    }
)
let accounts = [];
accounts.push(new ethers.Wallet.fromMnemonic(mnemonic,`m/44'/60'/0'/0/0`)); //0xd3a70caa19d72D9Ed09520594cae4eeA7812Ab51
accounts.push(new ethers.Wallet.fromMnemonic(mnemonic,`m/44'/60'/0'/0/1`)); //0x8dE0336bbF757a34444Ac13B3f51B42A75CbFCd9
accounts.push(new ethers.Wallet.fromMnemonic(mnemonic,`m/44'/60'/0'/0/2`)); //0x7BD21Ba85045A4D84e9d45597CbE1F656A0E7989
accounts.push(new ethers.Wallet.fromMnemonic(mnemonic,`m/44'/60'/0'/0/3`)); //0xB84bB304A73819e09B75599579Ff55f117beDA9a
accounts.push(new ethers.Wallet.fromMnemonic(mnemonic,`m/44'/60'/0'/0/4`)); //0x321fB1002DD7fa1e8D2Ad5F697ADCdD6dFA6da13
accounts.push(new ethers.Wallet(PK_NFT)); //0x5D6D33A0ee8d1e3ce23CFF2EA65b27609C62d869

for(let i = 0; i < accounts.length; i++){
    accounts[i] = accounts[i].connect(provider);
}

const nftTokens = [{tokenId: 5226, address: `0xc014b45d680b5a4bf51ccda778a68d5251c14b5e`, owner: accounts[5]},
    {tokenId: 25101, address: `0xdf7952b35f24acf7fc0487d01c8d5690a60dba07`, owner: accounts[5]},
    {tokenId: 10151, address: `0x9f0225d5c92b9cee4024f6406c4f13e546fd91a8`, owner: accounts[0]},
    {tokenId: 10000773814, address: `0x85F0e02cb992aa1F9F47112F815F519EF1A59E2D`, owner: accounts[5]},
    {tokenId: 2827, address: `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`, owner: accounts[5]}]

for(let i = 0 ;i < nftTokens.length; i++){
    nftTokens[i] = ({
        address:nftTokens[i].address,
        tokenId:nftTokens[i].tokenId,
        owner: nftTokens[i].owner,
        contract: new ethers.Contract(nftTokens[i].address, biswapNFTArtifact.abi, accounts[5])
    })
}

function expandTo18Decimals(n) {
    return (new BigNumber.from(n)).mul((new BigNumber.from(10)).pow(18))
}

async function numberLastBlock(){
    return (await ethers.provider.getBlock(`latest`)).number;
}

let tx, price, offerId, curTimestamp;

async function main(){

    const market = new ethers.Contract(marketAddress, marketArtifact.abi, accounts[0]);
    const dealToken = new ethers.Contract(bswTokenAddress, dealTokenArtifact.abi, accounts[0]);
    const auction = new ethers.Contract(auctionAddress, auctionArtifact.abi, accounts[0]);

    //MARKET ----------------------------------------------------------------------------------------------------------

    // console.log(`Approve token to market`)
    // await nftTokens[0].contract.connect(nftTokens[0].owner).setApprovalForAll(market.address, nftTokens[0].tokenId,  {gasLimit: 3000000});
    // await nftTokens[1].contract.connect(nftTokens[1].owner).setApprovalForAll(market.address, nftTokens[1].tokenId,  {gasLimit: 3000000});
    // await nftTokens[2].contract.connect(nftTokens[2].owner).setApprovalForAll(market.address, nftTokens[2].tokenId,  {gasLimit: 3000000});
    // await nftTokens[3].contract.connect(nftTokens[3].owner).setApprovalForAll(market.address, nftTokens[3].tokenId,  {gasLimit: 3000000});
    // await nftTokens[4].contract.connect(nftTokens[4].owner).setApprovalForAll(market.address, nftTokens[4].tokenId,  {gasLimit: 3000000});
    //
    // console.log(`Create sell offers`);
    // price = expandTo18Decimals(2);
    // tx = await market.connect(nftTokens[2].owner).offer(0, dealToken.address, nftTokens[2].address, nftTokens[2].tokenId, price, {gasLimit: 3000000});
    // await tx.wait();
    //
    // console.log(`Approve deal token to market contract`);
    // await dealToken.connect(accounts[0]).approve(market.address, expandTo18Decimals(1000), {gasLimit: 3000000});
    //
    // let offerId = await market.tokenSellOffers(nftTokens[2].address, nftTokens[2].tokenId);
    // console.log(`Accept sell offer ${offerId}`);
    // await market.connect(accounts[0]).accept(offerId, {gasLimit: 3000000});
    //
    //
    // price = expandTo18Decimals(1).div(100);
    // console.log(`Approve deal token to market contract`);
    // await dealToken.connect(accounts[5]).approve(market.address, expandTo18Decimals(1000), {gasLimit: 3000000});
    // console.log(`Create Buy offer`);
    // tx = await market.connect(accounts[5]).offer(1, dealToken.address, nftTokens[1].address, nftTokens[1].tokenId, price, {gasLimit: 3000000});
    // await tx.wait();
    //
    // offerId = await market.userBuyOffers(accounts[5].address, nftTokens[1].address, nftTokens[1].tokenId);
    // console.log(`Accept buy offer ${offerId}`);
    // tx = await market.connect(nftTokens[1].owner).accept(offerId, {gasLimit: 3000000});
    // console.log(await tx.wait());
    //
    // console.log(`Cancel offer`)
    // offerId = 3
    // tx = await market.connect(accounts[5]).cancel(offerId)
    // console.log(await tx.wait());
    //
    // console.log(`Create sell offers`)
    // price = expandTo18Decimals(2).div(105);
    // tx = await nftTokens[2].contract.connect(nftTokens[2].owner).setApprovalForAll(market.address, nftTokens[2].tokenId,  {gasLimit: 3000000});
    // await tx.wait();
    //
    // tx = await market.connect(nftTokens[2].owner).offer(0, dealToken.address, nftTokens[2].address, nftTokens[2].tokenId, price, {gasLimit: 3000000});
    // await tx.wait();
    //
    // tx = await market.connect(nftTokens[3].owner).offer(0, dealToken.address, nftTokens[3].address, nftTokens[3].tokenId, price, {gasLimit: 3000000});
    // await tx.wait();
    //
    // console.log(`Create Buy offers`);
    // price = expandTo18Decimals(1).div(50);
    // console.log(`Approve deal token to market contract`);
    // await dealToken.connect(accounts[1]).approve(market.address, expandTo18Decimals(1000), {gasLimit: 3000000});
    // console.log(`Create Buy offer`);
    // tx = await market.connect(accounts[1]).offer(1, dealToken.address, nftTokens[3].address, nftTokens[3].tokenId, price, {gasLimit: 3000000});
    // await tx.wait();
    //
    // console.log(`Create Buy offer`);
    // tx = await market.connect(accounts[1]).offer(1, dealToken.address, nftTokens[4].address, nftTokens[4].tokenId, price, {gasLimit: 3000000});
    // await tx.wait();


    //AUCTION ---------------------------------------------------------------------------------------------------------

    console.log(`Create sell token on auction`);
    console.log(`Approve token to auction`)
    await nftTokens[2].contract.connect(nftTokens[2].owner).setApprovalForAll(auction.address, nftTokens[2].tokenId,  {gasLimit: 3000000});
    curTimestamp = (await provider.getBlock(`latest`)).timestamp;
    let duration = 7200 //in seconds
    price = expandTo18Decimals(1).div(100);
    tx = await auction.connect(nftTokens[2].owner).sell([nftTokens[2].address, nftTokens[2].tokenId], dealToken.address, price, curTimestamp + duration,  {gasLimit: 3000000});
    await tx.wait();

    // console.log(`Cancel auction`)
    // tx = await auction.connect(nftTokens[0].owner).cancel(1,  {gasLimit: 3000000});

    let auctionId = await auction.auctionNftIndex(nftTokens[2].address, nftTokens[2].tokenId);

    console.log(`Approve deal token to market contract`);
    tx = await dealToken.connect(accounts[5]).approve(auction.address, expandTo18Decimals(1000), {gasLimit: 3000000});
    await tx.wait();

    console.log(`Make bid on auction ${auctionId.toString()}`)
    let minBidPrice = await auction.getMinBidPrice(auctionId);
    tx = await auction.connect(accounts[5]).bid(auctionId, minBidPrice,  {gasLimit: 3000000});
    await tx.wait();

    // console.log(`Close auction`);
    // tx = await auction.connect(accounts[1]).collect([auctionId]);
    // await tx.wait();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });