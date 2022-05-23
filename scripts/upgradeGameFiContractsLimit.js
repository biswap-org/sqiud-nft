//npx hardhat run scripts/upgradeGameFiContractsLimit.js --network mainnetBSC
const { ethers, network, upgrades} = require(`hardhat`);

const deployedGameContracts = require('./deployGameAddresses.json')

const gameAddress = deployedGameContracts.proxy_mainSquidGame

let game;

const toBN = (numb, power= 18) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const Game = await ethers.getContractFactory(`MainSquidGame`);

    // console.log(`Start deploying upgrade NFT game contract`);
    // game = await upgrades.upgradeProxy(gameAddress, Game, {nonce: ++nonce, gasLimit: 5e6});
    // await game.deployed();
    // nonce++;
    // console.log(`Main game upgraded`);


    game = await Game.attach(gameAddress);

    //Set contracts cost & limits
    const playerContractsV2 = {
        0: [15*24*3600, toBN(36525, 12), true], //15 days 0,035625 BSW
        1: [30*24*3600, toBN(7125, 13), true], //30 days 0.07125 BSW
    }

    console.log(`Set new contract V2 prices:`);
    for(let i in playerContractsV2){
        await game.changePlayerContract(i, 2, playerContractsV2[i], {nonce: ++nonce, gasLimit: 3e6});
        console.log(` - Player contract ${i} changed to ${playerContractsV2[i]}`);
    }

    console.log(`Set contracts limit`);
    await game.setPeriodLimitContracts(81900, toBN(30), true, {nonce: ++nonce, gasLimit: 5e6});
    console.log(`Contracts limits changed`)

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
