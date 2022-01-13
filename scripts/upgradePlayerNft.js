// npx hardhat flatten ./contracts/SquidPlayerNFT.sol > ./temp/flatten/SquidPlayerNFTFlatten.sol
//npx hardhat run scripts/upgradePlayerNft.js --network mainnetBSC
const { ethers, network, hardhat, upgrades} = require(`hardhat`);
const deployedContracts = require('./deployNFTAddresses.json')

//Owner 0xbafefe87d57d4c5187ed9bd5fab496b38abdd5ff

const playerNFTAddress = deployedContracts.proxy_squidPlayerNFT

let playerNft;

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    console.log(`Start deploying upgrade Player NFT contract`);
    const PlayerNft = await ethers.getContractFactory(`SquidPlayerNFT`);
    playerNft = await upgrades.upgradeProxy(playerNFTAddress, PlayerNft, {nonce: ++nonce, gasLimit: 5e6});
    await playerNft.deployed();
    console.log(`NFT player upgraded`);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
