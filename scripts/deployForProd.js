//npx hardhat run scripts/deployForTest.js --network testnetBSC
///Users/admin/Documents/BSW/GameFi/node_modules/@openzeppelin/upgrades-core/src/deployment.ts:70:15)
//Users/admin/Documents/BSW/GameFi/node_modules/@openzeppelin/upgrades-core/dist/deployment.js 46
const { ethers, network, upgrades } = require(`hardhat`);

const fs = require('fs')


const toWei = n => ethers.BigNumber.from(10).pow(18).mul(n);
const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

//squidBusNFT initialize parameters
const baseURIBusNFT = `` //TODO change in prod
const maxBusLevel = 5
const minBusBalance = 2
const maxBusBalance = 5
const busAdditionPeriod = 30 * 60 //7 * 3600*24 //7 days //TODO change in prod

//squidPlayerNFT initialize parameters
const baseURIPlayerNFT = `` //TODO change in prod

//game initialize parameters
const usdtTokenAddress = `0x55d398326f99059fF775485246999027B3197955`
const bswTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`
const oracleAddress = `0x2f48cde4cfd0fb4f5c873291d5cf2dc9e61f2db0`
const masterChefAddress = `0xDbc1A13490deeF9c3C12b44FE77b503c1B061739`
const autoBSWAddress = `0x97A16ff6Fd63A46bf973671762a39f3780Cda73D`
const treasuryAddress = `0xd3a70caa19d72D9Ed09520594cae4eeA7812Ab51` //TODO change in prod
const recoveryTime = 5 * 60 //48 * 3600 //48 hours //TODO change in prod

//NFTMinter initialize parameters
const treasuryAddressBus = `0xd3a70caa19d72D9Ed09520594cae4eeA7812Ab51`
const treasuryAddressPlayer = `0xd3a70caa19d72D9Ed09520594cae4eeA7812Ab51`
const busPriceInUSD = toBN(30,15)//toWei(30) //TODO change in prod
const playerPriceInUSD = toBN(30, 15) // toWei(30) //TODO change in prod


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

    console.log(`Start deploying SquidBusNFT contract`);
    squidBusNFT = await upgrades.deployProxy(SquidBusNFT, [baseURIBusNFT, maxBusLevel, minBusBalance, maxBusBalance, busAdditionPeriod], {nonce: ++nonce, gasLimit: 5e6});
    await squidBusNFT.deployed();
    console.log(`squidBusNFT deployed to ${squidBusNFT.address}`);


    console.log(`Start deploying squidPlayerNFT contract`);
    squidPlayerNFT = await upgrades.deployProxy(SquidPlayerNFT, [baseURIPlayerNFT], {nonce: ++nonce, gasLimit: 5e6});
    await squidPlayerNFT.deployed();
    console.log(`squidPlayerNFT deployed to ${squidPlayerNFT.address}`);

    // squidBusNFT = SquidBusNFT.attach(``);
    // squidPlayerNFT = SquidPlayerNFT.attach(``);
    // game = Game.attach(``)
    // nftMinter = NftMinter.attach(``)

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

        proxy_squidBusNFT:    squidBusNFT.address,
        proxy_squidPlayerNFT: squidPlayerNFT.address,
        proxy_mainSquidGame:  game.address,
        proxy_nftMinter:      nftMinter.address,

        imp_squidBusNFT:    await getImplementationAddress(squidBusNFT.address),
        imp_squidPlayerNFT: await getImplementationAddress(squidPlayerNFT.address),
        imp_mainSquidGame:  await getImplementationAddress(game.address),
        imp_nftMinter:      await getImplementationAddress(nftMinter.address)
    }
    fs.writeFileSync('deploymentCache.json', JSON.stringify(deployedContracts, null, 4), () => {
        console.log(deployedContracts)
    })


    // console.log(`squidBusNFT deployed to    ${squidBusNFT.address}`);
    // console.log(`squidPlayerNFT deployed to ${squidPlayerNFT.address}`);
    // console.log(`game deployed to           ${game.address}`);
    // console.log(`nftMinter deployed to      ${nftMinter.address}`);

    // console.log(`squidBusNFT implementation address:    `, await getImplementationAddress(squidBusNFT.address));
    // console.log(`squidPlayerNFT implementation address: `, await getImplementationAddress(squidPlayerNFT.address));
    // console.log(`game implementation address:           `, await getImplementationAddress(game.address));
    // console.log(`nftMinter implementation address:      `, await getImplementationAddress(nftMinter.address));

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
