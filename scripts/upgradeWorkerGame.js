// npx hardhat flatten ./contracts/SquidWorkerGame.sol > ./temp/flatten/SquidWorkerGameFlatten.sol
//npx hardhat run scripts/upgradeWorkerGame.js --network mainnetBSC
const { ethers, upgrades} = require(`hardhat`);
const deployedContracts = require('./deployWorkerGameAddresses.json')


const workerGameAddress = deployedContracts.proxy_staffWorkGame
let workerGame;

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    console.log(`Start deploying upgrade Worker staff game contract`);
    const StaffGameNft = await ethers.getContractFactory(`SquidWorkerGame`);
    workerGame = await upgrades.upgradeProxy(workerGameAddress, StaffGameNft);
    await workerGame.deployed();
    console.log(`Worker staff game upgraded`);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
