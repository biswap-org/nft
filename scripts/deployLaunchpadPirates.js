//npx hardhat run scripts/deployLaunchpadPirates.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

//Set parameters to launchpad
const treasuryAddress = `0x2c0445a18dAB9C37CDcD7002bF7e6D777094EDdF`;
//BSW token Address
const dealTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;
const autoBswAddress = `0xa4b20183039b2F9881621C3A03732fBF0bfdff10`;
const launchStartBlock = 15767260; //19:00
const price = toBN(125,18);

const shipsNFT = `0x3Df7076b8beb46Dc26017e1D46E0e7046A1Ca41F`;
const shipsVault = `0x4E0EBCF7652276806BA41922E343092B26b20eB4`;

const piratesNFT = `0xfa7eD23E2a5cd9C7B752288FbbA627CEcECCA928`;
const piratesVault = `0xea2d85cA476D675522Cc0f2Bb68431AB27b32721`;

const artNFT = `0xbd74bf73780096E12B8d9Df415d7Fe7dB55822eC`;
const artVault = `0xA175f8D6dAb99E1C31bA0a79e7a590Cc143E23D5`;

const sandboxNFT = `0xF261E1b48E57bB6b3345D0De11B86d390267387a`;
const sandboxVault = `0x1DEaa644720e5548A39b4D619423708e7226c9dA`;

let launchpad;

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    console.log(`Start deploy pirates launchpad`);
    const Launchpad = await ethers.getContractFactory('PiratesLaunchpad');
    launchpad = await Launchpad.deploy(dealTokenAddress, autoBswAddress, treasuryAddress, launchStartBlock, price, {nonce: ++nonce, gasLimit: 3e6});
    await launchpad.deployTransaction.wait();
    console.log(`Launchpad Random deployed to ${launchpad.address}`);

    console.log(`Add NFTs instances`);
    await launchpad.updateInstanceOfNFT(0, piratesNFT, piratesVault, {nonce: ++nonce, gasLimit: 3e6});
    await launchpad.updateInstanceOfNFT(1, shipsNFT, shipsVault, {nonce: ++nonce, gasLimit: 3e6});
    await launchpad.updateInstanceOfNFT(2, artNFT, artVault, {nonce: ++nonce, gasLimit: 3e6});
    await launchpad.updateInstanceOfNFT(3, sandboxNFT, sandboxVault, {nonce: ++nonce, gasLimit: 3e6});
    console.log(`Done`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
