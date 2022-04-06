const { network, ethers  } = require(`hardhat`);
const fs = require(`fs`)

const feeRewardAddress = `0x04eFD76283A70334C72BB4015e90D034B9F3d245`;
// const tokensList = `./tokens.json`;


async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    let SwapFeeReward = await ethers.getContractFactory(`SwapFeeRewardWithRB`);
    let swapFeeReward = await SwapFeeReward.attach(feeRewardAddress);

    // console.log(`Add tokens to white list in swap fee reward`);
    // let tokens = fs.readFileSync(tokensList, "utf-8");
    // tokens = JSON.parse(tokens);
    //
    // for (const item of tokens) {
    //     console.log(`Try to add token ${item.name} address ${item.address} to contract`);
    //     console.log(`nonce: `, nonce);
    //     let tx = await swapFeeReward.addWhitelist(item.address, {nonce: ++nonce, gasLimit: 3000000});
    //     await tx.wait();
    // }

    //function setPairEnabled(uint256 _pid, bool _enabled)
    console.log(`Remove pairs from feeReward`);
    let pidsToRemove = [17, 27, 28, 30, 31]
    for(const item of pidsToRemove){
        let tx = await swapFeeReward.setPairEnabled(item, false, {nonce: ++nonce, gasLimit: 3000000});
        await tx.wait();
    }

    console.log(`Add pairs to swap fee reward`);
    let pairs = [
      `0x16da0c473214717383b7Ef5cdE71c723584f8ac4`,
      `0xDE5e03bC7014D65aF8F9fe8F11FDb5B5b9116F7b`,
      `0xfbbd096A99e95D6808b918A5C0863ed9989EBd41`,
      `0x857f601Df3Eac2f25E25dBd2B33D94bCd6F47d1C`,
      `0xedc3f1edB8811d2aE4aD6666D77521ae817F2ef1`,
      `0x8410c28A6e4074a148F9205712C6b54d12F7282C`,
      `0x76e1B3B2B15A4Ff61aB3E245d6b98ae808DEe6e1`,
      `0x4c2139aBcaF1981d4AB0Df2dfD6Ee78422e0E76F`,
      `0xe41F46AEF7594Cc43FC57edf2b0fDC377900BC4E`,
      `0x19058558Bbc66C2Dd97c5cA8a189d350A34e4423`,
      `0x38fd42c46Cb8Db714034dF920f6663b31Bb63DDe`,
      `0x49859419c83465eeeEdD7b1D30dB99CE58C88Ec3`,
      `0x7bfCd2bda87fd2312A946BD9b68f5Acc6E21595a`,
      `0x3B09e13Ca9189FBD6a196cfE5FbD477C885afBf3`,
      `0x9C3d4Fb14D3A021aee4Fd763506B1F71d509Dc90`,
      `0x3530F7d8D55c93D778e17cbd30bf9eB07b884f35`,
      `0x2f3899fFB9FdCf635132F7bb94c1a3A0F906cc6f`,
      `0xe0E9FDd2F0BcdBcaF55661B6Fa1efc0Ce181504b`,
      `0x4F00ADEED60FCba76e58a5d067b6A4b9Daf8e30f`,
      `0x7683f8349376F297138D3082e236F0E34aF1D1c3`,
      `0x5a36E9659F94F27e4526DDf6Dd8f0c3B3386D7F3`,
      `0xe73fe11863e4C3714EAFDee832a0987b33651f27`,
      `0x923dD5668A0F373B714f8D230425ed7799c5d63D`,
      `0xB0c7DC6f0b67210708a22ab543480F162C24d110`,
      `0x933cE2c915cA4e97c68E8d197589A4213B1eC858`,
      `0xc2619B94d60223db62991a1DB937D723A2Ed6217`,
      `0x1Cba970a6E06d4BcC0c4717BE677d1A8AA0211DA`
    ]
    for (const item of pairs) {
        console.log(`Try add pair with address ${item} percent 49`);
        let tx = await swapFeeReward.addPair(49, item, {nonce: ++nonce, gasLimit: 3000000});
        await tx.wait();
    }


    // let pairs = fs.readFileSync(`./Pair list.json`, "utf-8");
    // pairs = JSON.parse(pairs);
    //
    // for (const item of pairs) {
    //     if (item.enabled) {
    //         console.log(`Try add pair ${item.name.symbolA}/${item.name.symbolB} with address ${item.address} percent ${item.percent}`);
    //         console.log(`nonce: `, nonce);
    //         let tx = await swapFeeReward.addPair(item.percent, item.address, {nonce: ++nonce, gasLimit: 3000000});
    //         await tx.wait();
    //     }
    // }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
