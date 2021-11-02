const { network, ethers  } = require(`hardhat`);
const fs = require(`fs`)

const feeRewardAddress = `0x3Aa5ebB10DC797CAC828524e59A333d0A371443c`;
const tokensList = `./tokens.json`;


async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);

    let SwapFeeReward = await ethers.getContractFactory(`SwapFeeRewardWithRB`);
    let swapFeeReward = await SwapFeeReward.attach(feeRewardAddress);

    console.log(`Add tokens to white list in swap fee reward`);
    let tokens = fs.readFileSync(tokensList, "utf-8");
    tokens = JSON.parse(tokens);

    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;
    for (const item of tokens) {
        console.log(`Try to add token ${item.name} address ${item.address} to contract`);
        console.log(`nonce: `, parseInt(nonce, 16));
        let tx = await swapFeeReward.addWhitelist(item.address, {nonce: ++nonce});
        await tx.wait();
    }

    console.log(`Add pairs to swap fee reward`);
    let pairs = fs.readFileSync(`./Pair list.json`, "utf-8");
    pairs = JSON.parse(pairs);

    for (const item of pairs) {
        if (item.enabled) {
            console.log(`Try add pair ${item.name.symbolA}/${item.name.symbolB} with address ${item.address} percent ${item.percent}`);
            console.log(`nonce: `, parseInt(nonce, 16));
            let tx = await swapFeeReward.addPair(item.percent, item.address, {nonce: ++nonce});
            await tx.wait();
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
