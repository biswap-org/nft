//npx hardhat run scripts/deployRBtoSE.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);
const {BigNumber} = require("ethers");

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`;
const squidPlayerNFTAddress = `0xb00ED7E3671Af2675c551a1C26Ffdcc5b425359b`;
const burnRBPeriod = 10;
const exchangeRate = toBN(20, 3);
const divisor = toBN(1, 3);

const RB_SETTER_ROLE = `0xc7c9819f33f023fb575ae9b63a0181942ca5956a309f3641e15d6dc199033e46`;
const SE_BOOST_ROLE = `0xfca6bac8781bc66ef196bb85acbfc743e952d50480437ed109b46e883bda687b`;

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address }`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;

    const Exchange = await ethers.getContractFactory(`RBToSEExchange`);
    const exchange = await Exchange.deploy(
        biswapNFTAddress,
        squidPlayerNFTAddress,
        burnRBPeriod,
        exchangeRate,
        divisor,
        {nonce: ++nonce, gasLimit: 3000000}
    )
    await exchange.deployTransaction.wait();
    console.log(`RB to SE Exchanger deployed to  ${exchange.address}`);
    console.log(`Set role to Biswap NFT`);
    const BiswapNFT = await ethers.getContractFactory('BiswapNFT');
    const biswapNFT = await BiswapNFT.attach(biswapNFTAddress);
    await biswapNFT.grantRole(RB_SETTER_ROLE, exchange.address, {nonce: ++nonce, gasLimit: 3000000});

    console.log(`Set role to Squid Player NFT`);
    const SquidPlayerNFTABI = [{
        "inputs": [
            {
                "internalType": "bytes32",
                "name": "role",
                "type": "bytes32"
            },
            {
                "internalType": "address",
                "name": "account",
                "type": "address"
            }
        ],
        "name": "grantRole",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }];
    const squidPlayerNFT = await ethers.getContractAt(SquidPlayerNFTABI, squidPlayerNFTAddress);
    await squidPlayerNFT.grantRole(SE_BOOST_ROLE, exchange.address, {nonce: ++nonce, gasLimit: 3000000});

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

