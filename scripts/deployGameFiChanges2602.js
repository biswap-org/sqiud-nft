//npx hardhat run scripts/deployGameFiChanges2602.js --network mainnetBSC
const { ethers, network, upgrades} = require(`hardhat`);
const deployedNFTContracts = require('./deployNFTAddresses.json')
const deployedGameContracts = require('./deployGameAddresses.json')
const {min} = require("mocha/lib/reporters");

const gameNFTAddress = deployedNFTContracts.proxy_mainSquidGame
const nftMinterAddress = deployedNFTContracts.proxy_nftMinter
const playerNFTAddress = deployedGameContracts.proxy_squidPlayerNFT


let playerNft, nftMinter, gameNft;

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const PlayerNft = await ethers.getContractFactory(`SquidPlayerNFT`);
    const GameNft = await ethers.getContractFactory(`MainSquidGame`);
    const NftMinter = await ethers.getContractFactory(`NFTMinter`);

    console.log(`Start deploying upgrade Player NFT contract`);
    playerNft = await upgrades.upgradeProxy(playerNFTAddress, PlayerNft, {nonce: ++nonce, gasLimit: 5e6});
    await playerNft.deployed();
    nonce++;
    console.log(`NFT player upgraded`);

    console.log(`Start deploying upgrade NFT game contract`);
    gameNft = await upgrades.upgradeProxy(gameNFTAddress, GameNft, {nonce: ++nonce, gasLimit: 5e6});
    await gameNft.deployed();
    nonce++;
    console.log(`NFT game upgraded`);

    console.log(`Start deploying upgrade NFT minter contract`);
    nftMinter = await upgrades.upgradeProxy(nftMinterAddress, NftMinter, {nonce: ++nonce, gasLimit: 5e6});
    await nftMinter.deployed();
    nonce++;
    console.log(`NFT minter upgraded`);

    playerNft = await PlayerNft.attach(playerNFTAddress);
    gameNft = await GameNft.attach(gameNFTAddress);
    nftMinter = await NftMinter.attach(nftMinterAddress);

    const playerContracts = {
        0: [15*24*3600, toBN(24, 18), true], //15 days
        1: [30*24*3600, toBN(456, 17), true], //30 days
        2: [0, 0, false] //60 days
    }

    console.log(`Set new contract prices:`);
    for(let i in playerContracts){
        await gameNft.changePlayerContract(i, playerContracts[i], {nonce: ++nonce, gasLimit: 3e6});
        console.log(` - Player contract ${i} changed to ${playerContracts[i]}`);
    }

    console.log(`Disable player mint`);
    await nftMinter.setPeriodLimitPlayers(0, true);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
