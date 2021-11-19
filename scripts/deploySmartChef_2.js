const { ethers, network } = require(`hardhat`)
const {BigNumber} = require("ethers")
const hre = require("hardhat")

const expandTo18Decimals = n => (new BigNumber.from(n)).mul((new BigNumber.from(10)).pow(18))


async function main() {
    const curBlockNumber = (await ethers.provider.getBlock('latest')).number;
    const accounts = await ethers.getSigners()
    const SmartChef = await ethers.getContractFactory(`SmartChefV2`)

    const endOfStake = curBlockNumber + 2592000;
    console.log(`curBlockNumber`, curBlockNumber);
    const rewardPerBlockBSW = new BigNumber.from(`42824074074074000`);
    const rewardPerBlockETERNAL = new BigNumber.from(`6172839506173000`);
    let nonce = await network.provider.send("eth_getTransactionCount", [accounts[0].address, "latest"])
    
    console.log(`deployer address: ${accounts[0].address}, current nonce: ${+nonce}`)

    const bswTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`
    const ETERNALTokenAddress = '0xd44fd09d74cd13838f137b590497595d6b3feea4'

    const smartChef = await SmartChef.deploy(ETERNALTokenAddress, endOfStake, {nonce: nonce++, gasLimit: 3e6})
    await smartChef.deployTransaction.wait()

    console.log(`smartChef deployed on ${smartChef.address} with stake token ${ETERNALTokenAddress}.\nStake will end in block ${endOfStake}.`)

    console.log(`initializing reward tokens`)

    await smartChef.addNewTokenReward(bswTokenAddress, 0, rewardPerBlockBSW, {nonce: nonce++, gasLimit: 3e6})
    console.log(`\t- ${bswTokenAddress} done`)
    await smartChef.addNewTokenReward(ETERNALTokenAddress, 0, rewardPerBlockETERNAL, {nonce: nonce++, gasLimit: 3e6})
    console.log(`\t- ${ETERNALTokenAddress} done`)

    console.log(`try to verify contract`)

    console.log(`awaiting for 20 sec...`)
    await sleep(20e3)


    // const smartChefAddress = '0x4c231A01917Ed76ae1EecF9b96Da8131401a0773';
    await hre.run("verify:verify", {
        address: smartChef.address,
        contract:`contracts/SmartChefV2.sol:SmartChefV2`,
        constructorArguments: [ETERNALTokenAddress, endOfStake]
    })
    .then(console.log)
    .catch(error => console.error(error.message))

    console.log({
        deployer: accounts[0].address,
        SmartChefV2: smartChef.address,
        rewardToken: bswTokenAddress,
        stakeToken: ETERNALTokenAddress,
        endBlock: endOfStake,
        rewardPerBlockBSW: +rewardPerBlockBSW,
        rewardPerBlockETERNAL: +rewardPerBlockETERNAL,
        dateOfDeployment: (new Date()).toLocaleDateString()
    })
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })


function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}