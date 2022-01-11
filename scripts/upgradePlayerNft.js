// npx hardhat flatten ./contracts/SquidPlayerNFT.sol > ./temp/flatten/SquidPlayerNFTFlatten.sol
//npx hardhat run scripts/upgradePlayerNft.js --network mainnetBSC
const { ethers, network, hardhat, upgrades} = require(`hardhat`);
const deployedContracts = require('../deployNFTAddresses.json')

const playerNFTAddress = deployedContracts.proxy_squidPlayerNFT

let playerNft;

//lock timestamp parameters
let mintLockStartTime;
const mintLockTimeDuration = 3600*24*7; // 7 days duration

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    console.log(`Start deploying upgrade Player NFT contract`);
    const PlayerNft = await ethers.getContractFactory(`SquidPlayerNFT`);
    playerNft = await upgrades.upgradeProxy(playerNFTAddress, PlayerNft, {nonce: ++nonce, gasLimit: 5e6});
    await playerNft.deployed();
    console.log(`NFT player upgraded`);

    mintLockStartTime = (await ethers.provider.getBlock('latest')).timestamp;
    console.log(`Set lock timestamp parameters: start timestamp: ${mintLockStartTime}, lock duration ${mintLockTimeDuration}`);

    let tx = await playerNft.setMintLockTime(mintLockTimeDuration, mintLockStartTime, {nonce: ++nonce, gasLimit: 5e6});
    console.log(`Transaction status`, (await tx.wait()).status)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
