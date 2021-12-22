// npx hardhat flatten ./contracts/MainSquidGame.sol > ./temp/flatten/MainSquidGameFlatten.sol
//npx hardhat run scripts/upgradeGameNft.js --network mainnetBSC
const { ethers, network, hardhat, upgrades} = require(`hardhat`);
const deployedContracts = require('../deployGameAddresses.json')


const gameNFTAddress = deployedContracts.proxy_mainSquidGame
let gameNft;

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    console.log(`Start deploying upgrade Game NFT contract`);
    const GameNft = await ethers.getContractFactory(`MainSquidGame`);
    gameNft = await upgrades.upgradeProxy(gameNFTAddress, GameNft);
    await gameNft.deployed();
    console.log(`NFT game upgraded`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });