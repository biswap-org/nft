//npx hardhat run scripts/deployLaunchpadPirates.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);


const launchStartBlock = 15767260; //19:00

const launchpadAddress = `0x1645C2D2A9F40FED4204BBe14FBBc706651C53B7`;

let launchpad;

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    console.log(`Start deploy pirates launchpad`);
    const Launchpad = await ethers.getContractFactory('PiratesLaunchpad');
    launchpad = await Launchpad.attach(launchpadAddress);

    console.log(`change start block`);
    // await launchpad.updateStartTimestamp(launchStartBlock, {nonce: ++nonce, gasLimit: 3e6});
    await launchpad.pause();
    console.log(`Done`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
