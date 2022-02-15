//npx hardhat run scripts/updateGameParam1502.js --network mainnetBSC

const { ethers, network } = require(`hardhat`);
const deployedContracts = require('./deployGameAddresses.json')

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const gameNFTAddress = deployedContracts.proxy_mainSquidGame;

let gameNft;

//15 days 21$
// 30 days 39,9$
// 60 days 71,4$
const playerContracts = {
    0: [15*24*3600, toBN(24, 18), true], //15 days
    1: [30*24*3600, toBN(456, 17), true], //30 days
    2: [60*24*3600, toBN(816,17), true] //60 days
}

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;
    console.log(`nonce: ${+nonce}`);

    const GameNft = await ethers.getContractFactory(`MainSquidGame`);
    gameNft = await GameNft.attach(gameNFTAddress);

    //Task BSW-1499
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
