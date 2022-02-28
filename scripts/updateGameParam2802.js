//npx hardhat run scripts/updateGameParam2802.js --network mainnetBSC

const { ethers, network } = require(`hardhat`);
const deployedContracts = require('./deployGameAddresses.json')


const gameNFTAddress = deployedContracts.proxy_mainSquidGame;

let gameNft;

//disable contracts
const playerContracts = {
    0: [0, 0, false], //15 days
    1: [0, 0, false], //30 days
    2: [0, 0, false] //60 days
}

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;
    console.log(`nonce: ${+nonce}`);

    const GameNft = await ethers.getContractFactory(`MainSquidGame`);
    gameNft = await GameNft.attach(gameNFTAddress);

    //Task number "unknown"
    console.log(`Set new contract prices:`);
    for(let i in playerContracts){
        await gameNft.changePlayerContract(i, playerContracts[i], {nonce: ++nonce, gasLimit: 3e6});
        console.log(` - Player contract ${i} changed to ${playerContracts[i]}`);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
