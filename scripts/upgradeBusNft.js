// npx hardhat flatten ./contracts/SquidBusNFT.sol > ./temp/flatten/SquidBusNFTFlatten.sol
//npx hardhat run scripts/upgradeBusNft.js --network mainnetBSC
const { ethers, network, hardhat, upgrades} = require(`hardhat`);
const deployedContracts = require('./deployNFTAddresses.json')

const busNFTAddress = deployedContracts.proxy_squidBusNFT
let busNft;

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    console.log(`Start deploying upgrade Bus NFT contract`);
    const BusNft = await ethers.getContractFactory(`SquidBusNFT`);
    busNft = await upgrades.upgradeProxy(busNFTAddress, BusNft);
    await busNft.deployed();
    console.log(`Bus NFT upgraded`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });