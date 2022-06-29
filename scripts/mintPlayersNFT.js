//npx hardhat run scripts/mintPlayersNFT.js --network mainnetBSC

const { ethers, network } = require(`hardhat`);
const deployedContracts = require('./deployNFTAddresses.json')

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const playerNFTAddress = deployedContracts.proxy_squidPlayerNFT;
const busNFTAddress = deployedContracts.proxy_squidBusNFT;
const owner = `0xbafefe87d57d4c5187ed9bd5fab496b38abdd5ff`
const receiverAddress = `0x04F2DdF4FA327323202a9B8714a173D7Af0fE6a0`
const TOKEN_MINTER_ROLE = `0x262c70cb68844873654dc54487b634cb00850c1e13c785cd0d96a2b89b829472`
let playerNFT, busNFT;

const currentTimestamp = async () => (await ethers.provider.getBlock('latest')).timestamp

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;

    const PlayerNFT = await ethers.getContractFactory(`SquidPlayerNFT`);
    const BusNFT = await ethers.getContractFactory(`SquidBusNFT`);
    playerNFT = await PlayerNFT.attach(playerNFTAddress);
    busNFT = await BusNFT.attach(busNFTAddress);

    //Task BSW-2290

    const endContractTimestamp = await currentTimestamp() + 86400*15;

    console.log(`Mint player NFT tokens`);
    await playerNFT.mint(receiverAddress, toBN(1000,18), endContractTimestamp, 1, {nonce: ++nonce, gasLimit: 3e6});
    await playerNFT.mint(receiverAddress, toBN(1000,18), endContractTimestamp, 1, {nonce: ++nonce, gasLimit: 3e6});
    await playerNFT.mint(receiverAddress, toBN(1000,18), endContractTimestamp, 1, {nonce: ++nonce, gasLimit: 3e6});
    // await playerNFT.mint(receiverAddress, toBN(1500,18), 1655385843, 2, {nonce: ++nonce, gasLimit: 3e6});

    // console.log(`Mint Buses`)
    // await busNFT.mint(receiverAddress, 5, {nonce: ++nonce, gasLimit: 3e6});
    // await busNFT.mint(receiverAddress, 5, {nonce: ++nonce, gasLimit: 3e6});
    // await busNFT.mint(receiverAddress, 5, {nonce: ++nonce, gasLimit: 3e6});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
