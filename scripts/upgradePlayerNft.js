// npx hardhat flatten ./contracts/SquidPlayerNFT.sol > ./temp/flatten/SquidPlayerNFTFlatten.sol
//npx hardhat run scripts/upgradePlayerNft.js --network mainnetBSC
const { ethers, network, hardhat, upgrades} = require(`hardhat`);
const deployedContracts = require('../deployNFTAddresses.json')

const playerNFTAddress = deployedContracts.proxy_squidPlayerNFT

let playerNft;

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    console.log(`Start deploying upgrade Player NFT contract`);
    const PlayerNft = await ethers.getContractFactory(`SquidPlayerNFT`);
    playerNft = await upgrades.upgradeProxy(playerNFTAddress, PlayerNft);
    await playerNft.deployed();
    console.log(`NFT player upgraded`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });