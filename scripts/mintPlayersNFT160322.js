//npx hardhat run scripts/updateGameParam2002.js --network mainnetBSC

const { ethers, network } = require(`hardhat`);
const deployedContracts = require('./deployNFTAddresses.json')

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const playerNFTAddress = deployedContracts.proxy_squidPlayerNFT;
const owner = `0xbafefe87d57d4c5187ed9bd5fab496b38abdd5ff`
const receiverAddress = `0x04F2DdF4FA327323202a9B8714a173D7Af0fE6a0`
const TOKEN_MINTER_ROLE = `0x262c70cb68844873654dc54487b634cb00850c1e13c785cd0d96a2b89b829472`
let playerNFT;


async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;
    console.log(`nonce: ${+nonce}`);

    const PlayerNFT = await ethers.getContractFactory(`SquidPlayerNFT`);
    playerNFT = await PlayerNFT.attach(playerNFTAddress);

    //Task BSW-1660
    console.log(`Add minter role to owner`)
    await playerNFT.grantRole(TOKEN_MINTER_ROLE, owner, {nonce: ++nonce, gasLimit: 3e6});

    console.log(`Mint player NFT tokens`);
    for(let i = 0;  i < 4; i++){
        await playerNFT.mint(receiverAddress, toBN(900,18), 1655385843, 1, {nonce: ++nonce, gasLimit: 3e6});
        console.log(`token #${+i+1} minted`);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
