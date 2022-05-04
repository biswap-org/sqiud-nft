//npx hardhat run scripts/upgradeGameFiContractsLimit.js --network mainnetBSC
const { ethers, network, upgrades} = require(`hardhat`);

const deployedGameContracts = require('./deployGameAddresses.json')

const gameAddress = deployedGameContracts.proxy_mainSquidGame

let game;

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const Game = await ethers.getContractFactory(`MainSquidGame`);

    console.log(`Start deploying upgrade NFT game contract`);
    game = await upgrades.upgradeProxy(gameAddress, Game, {nonce: ++nonce, gasLimit: 5e6});
    await game.deployed();
    nonce++;
    console.log(`Main game upgraded`);

    console.log(`Set contracts limit`);
    await game.setPeriodLimitContracts(1000000, true, {nonce: ++nonce, gasLimit: 5e6});

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
