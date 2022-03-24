//npx hardhat run scripts/mintPlayersNFT160322.js --network mainnetBSC

const { ethers, network } = require(`hardhat`);
const deployedContracts = require('./deployNFTAddresses.json')

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const playerNFTAddress = deployedContracts.proxy_squidPlayerNFT;
const busNFTAddress = deployedContracts.proxy_squidBusNFT;
const owner = `0xbafefe87d57d4c5187ed9bd5fab496b38abdd5ff`
const receiverAddress = `0xAA3f6b012fCBb85AA6d6c77B866395B5bD7ffF09`
const TOKEN_MINTER_ROLE = `0x262c70cb68844873654dc54487b634cb00850c1e13c785cd0d96a2b89b829472`
let playerNFT, busNFT;


async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;

    const PlayerNFT = await ethers.getContractFactory(`SquidPlayerNFT`);
    const BusNFT = await ethers.getContractFactory(`SquidBusNFT`);
    playerNFT = await PlayerNFT.attach(playerNFTAddress);
    busNFT = await BusNFT.attach(busNFTAddress);

    //Task BSW-1660
    // console.log(`Add minter role to owner`)
    // await playerNFT.grantRole(TOKEN_MINTER_ROLE, owner, {nonce: ++nonce, gasLimit: 3e6});
    // await busNFT.grantRole(TOKEN_MINTER_ROLE, owner, {nonce: ++nonce, gasLimit: 3e6});

    console.log(`Mint player NFT tokens`);
    await playerNFT.mint(receiverAddress, toBN(900,18), 1655385843, 1, {nonce: ++nonce, gasLimit: 3e6});
    await playerNFT.mint(receiverAddress, toBN(1500,18), 1655385843, 2, {nonce: ++nonce, gasLimit: 3e6});
    // await playerNFT.mint(receiverAddress, toBN(1500,18), 1655385843, 2, {nonce: ++nonce, gasLimit: 3e6});
    // await playerNFT.mint(receiverAddress, toBN(300,18), 0, 1, {nonce: ++nonce, gasLimit: 3e6});
    // await playerNFT.mint(receiverAddress, toBN(500,18), 0, 2, {nonce: ++nonce, gasLimit: 3e6});
    // await playerNFT.mint(receiverAddress, toBN(1500,18), 0, 3, {nonce: ++nonce, gasLimit: 3e6});
    // console.log(`Mint Buses`)
    // await busNFT.mint(receiverAddress, 5, {nonce: ++nonce, gasLimit: 3e6});
    // await busNFT.mint(receiverAddress, 5, {nonce: ++nonce, gasLimit: 3e6});
    // await busNFT.mint(receiverAddress, 5, {nonce: ++nonce, gasLimit: 3e6});
console.log()
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
