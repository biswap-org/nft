const hre = require('hardhat');

const biswapNFTAddress = ``;

async function main() {

    console.log(`Verify Biswap NFT contract`);

    let res = await hre.run("verify:verify", {
        address: biswapNFTAddress,
        constructorArguments: []
    })
    console.log(res);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });