//npx hardhat run scripts/mintNFTTokens.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`
const to = `0xe843116517809C0d59c8a19dA4f7684f1d34433B`
const bsPlayersAddress = `0xb00ED7E3671Af2675c551a1C26Ffdcc5b425359b`
const bsBusesAddress = '0x6d57712416eD4890e114A37E2D84AB8f9CEe4752'

const TOKEN_MINTER_ROLE = '0x262c70cb68844873654dc54487b634cb00850c1e13c785cd0d96a2b89b829472'

let biswapNft, bsplayers, bsbuses

//Task: BSW-1779
async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`);
    biswapNft = await BiswapNFT.attach(biswapNFTAddress);
    bsplayers = await ethers.getContractAt(require(`../ABIs/bspContract.json`), bsPlayersAddress);
    bsbuses = await ethers.getContractAt(require(`../ABIs/bsbContract.json`), bsBusesAddress);

    // console.log(`Set minter role to buses contract`);
    // await bsbuses.grantRole(TOKEN_MINTER_ROLE, deployer.address, {nonce: ++nonce, gasLimit: 5e6});

    console.log(`Mint tokens:`);
    console.log(`   - Mint Robi token`);
    await biswapNft.launchpadMint(to, 1, toBN(1,18), {nonce: ++nonce, gasLimit: 5e6});

    console.log(`   - Mint Bus token`);
    await bsbuses.mint(to, 2, {nonce: ++nonce, gasLimit: 5e6});

    console.log(`   - Mint Player token`);
    await bsplayers.mint(to, toBN(1000, 18), 0, 1, {nonce: ++nonce, gasLimit: 5e6});

    console.log(`Done`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
