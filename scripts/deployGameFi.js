//npx hardhat run scripts/deployGameFi.js --network mainnetBSC

const { ethers, network, upgrades } = require(`hardhat`);
const deployedNFTContracts = require('../deployNFTAddresses.json')

const fs = require('fs')


const toWei = n => ethers.BigNumber.from(10).pow(18).mul(n);
const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);


//game initialize parameters
const usdtTokenAddress = `0x55d398326f99059fF775485246999027B3197955`
const bswTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`
const oracleAddress = `0x2f48cde4cfd0fb4f5c873291d5cf2dc9e61f2db0`
const masterChefAddress = `0xDbc1A13490deeF9c3C12b44FE77b503c1B061739`
const autoBSWAddress = `0x97A16ff6Fd63A46bf973671762a39f3780Cda73D`
const treasuryAddress = `0x9D7Fe368a2AB44Bab883485F48a2D07B994C581F`
const recoveryTime = 48 * 3600

//NFTMinter initialize parameters
const treasuryAddressBus = `0xf81FeB1cEBe8bBA613ebB65d7d3dDc3ec6b8204c`
const treasuryAddressPlayer = `0xE209A24abE11a588Fb656498Db23ef409cC46F6c`
const busPriceInUSD = toWei(30)
const playerPriceInUSD = toWei(30)


let squidBusNFT, squidPlayerNFT, game, nftMinter


async function getImplementationAddress(proxyAddress) {
    const implHex = await ethers.provider.getStorageAt(
        proxyAddress,
        "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    );
    return ethers.utils.hexStripZeros(implHex);
}

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const SquidBusNFT = await ethers.getContractFactory(`SquidBusNFT`);
    const SquidPlayerNFT = await ethers.getContractFactory(`SquidPlayerNFT`);
    const Game = await ethers.getContractFactory(`MainSquidGame`);
    const NftMinter = await ethers.getContractFactory(`NFTMinter`);

    squidBusNFT = SquidBusNFT.attach(deployedNFTContracts.proxy_squidBusNFT);
    squidPlayerNFT = SquidPlayerNFT.attach(deployedNFTContracts.proxy_squidPlayerNFT);


    console.log(`Start deploying game contract`);
    game = await upgrades.deployProxy(
        Game,
        [
            usdtTokenAddress,
            bswTokenAddress,
            squidBusNFT.address,
            squidPlayerNFT.address,
            oracleAddress,
            masterChefAddress,
            autoBSWAddress,
            treasuryAddress,
            recoveryTime],
        {nonce: ++nonce, gasLimit: 5e6}
    );
    await game.deployed();
    console.log(`game deployed to ${game.address}`);


    console.log(`Start deploying nftMinter contract`);
    nftMinter = await upgrades.deployProxy(NftMinter,
        [
            usdtTokenAddress,
            bswTokenAddress,
            squidBusNFT.address,
            squidPlayerNFT.address,
            oracleAddress,
            treasuryAddressBus,
            treasuryAddressPlayer,
            busPriceInUSD,
            playerPriceInUSD
        ],
        {nonce: ++nonce, gasLimit: 5e6});
    await nftMinter.deployed();

    const deployedContracts = {
        deployTime:     new Date().toLocaleString(),

        proxy_mainSquidGame:  game.address,
        proxy_nftMinter:      nftMinter.address,

        imp_mainSquidGame:  await getImplementationAddress(game.address),
        imp_nftMinter:      await getImplementationAddress(nftMinter.address)
    }
    fs.writeFileSync('deployGameAddresses.json', JSON.stringify(deployedContracts, null, 4), () => {
        console.log(deployedContracts)
    })
        console.log(deployedContracts)

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
