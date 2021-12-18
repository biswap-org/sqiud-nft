const { ethers, network, upgrades } = require(`hardhat`);
const {BigNumber} = require("ethers");

const toWei = n => ethers.BigNumber.from(10).pow(18).mul(n);
const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const deployedContracts = require('deploymentCache.json')

const squidBusNFTAddress    = deployedContracts.proxy_squidBusNFT
const squidPlayerNFTAddress = deployedContracts.proxy_squidPlayerNFT
const gameAddress           = deployedContracts.proxy_mainSquidGame
const nftMinterAddress      = deployedContracts.proxy_nftMinter

let squidBusNFT, squidPlayerNFT, game, nftMinter

const TOKEN_MINTER_ROLE     = `0x262c70cb68844873654dc54487b634cb00850c1e13c785cd0d96a2b89b829472`;
const GAME_ROLE             = `0x6a64baf327d646d1bca72653e2a075d15fd6ac6d8cbd7f6ee03fc55875e0fa88`;
const SE_BOOST_ROLE         = `0xfca6bac8781bc66ef196bb85acbfc743e952d50480437ed109b46e883bda687b`;
const DEFAULT_ADMIN_ROLE    = `0x0000000000000000000000000000000000000000000000000000000000000000`;

//Game parameters
const decreaseWithdrawalFeeByDay = 150 //withdrawalFee decrease on 1,5% by day
const withdrawalFee = 2700 //Initial fee 27%

const enableSeDivide = true //Enabled
const seDivide = 100 // 1% by game
const gracePeriod =  45*60 //45*3600*24 //45 days //TODO change in prod


const playerContracts = { //TODO change in prod
    1: [1296000, toBN(15, 15), true],//[1296000, toBN(15, 18), true],
    2: [2592000, toBN(279, 14), true], //[2592000, toBN(279, 17), true],
    3: [5184000, toBN(51,15),true] //[5184000, toBN(51,18),true]
}


const games = {
    1: [
        toWei(1000),  //minSeAmount
        toWei(30),  //minStakeAmount
        8900, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(76,17), 0] //rewardTokens: [address, rewardInUSD, rewardInToken]
        ],
        `First game name`, //game name
        true //Enabled
    ],
    2: [
        toWei(2000),  //minSeAmount
        toWei(40),  //minStakeAmount
        8800, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(155,17), 0] //rewardTokens: [address, rewardInUSD, rewardInToken]
        ],
        `Second game name`, //game name
        true //Enabled
    ],
    3: [
        toWei(3000),  //minSeAmount
        toWei(50),  //minStakeAmount
        8700, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(236,17), 0] //rewardTokens: [address, rewardInUSD, rewardInToken]
        ],
        `Third game name`, //game name
        true //Enabled
    ],
    4: [
        toWei(4000),  //minSeAmount
        toWei(60),  //minStakeAmount
        8600, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(160,17), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
            [`0x55d398326f99059fF775485246999027B3197955`, 0, toBN(160,17)]
        ],
        `Fourth game name`, //game name
        true //Enabled
    ],
    5: [
        toWei(5000),  //minSeAmount
        toWei(70),  //minStakeAmount
        8500, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(407,17), 0] //rewardTokens: [address, rewardInUSD, rewardInToken]
        ],
        `Fifth game name`, //game name
        true //Enabled
    ],
    6: [
        toWei(6000),  //minSeAmount
        toWei(80),  //minStakeAmount
        8400, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(492,17), 0] //rewardTokens: [address, rewardInUSD, rewardInToken]
        ],
        `Sixth game name`, //game name
        true //Enabled
    ],
    7: [
        toWei(7000),  //minSeAmount
        toWei(90),  //minStakeAmount
        8300, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(600,17), 0] //rewardTokens: [address, rewardInUSD, rewardInToken]
        ],
        `Seventh game name`, //game name
        true //Enabled
    ]
}

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;
    console.log(`nonce: ${+nonce}`);

    const SquidBusNFT = await ethers.getContractFactory(`SquidBusNFT`);
    const SquidPlayerNFT = await ethers.getContractFactory(`SquidPlayerNFT`);
    const Game = await ethers.getContractFactory(`MainSquidGame`);
    const NftMinter = await ethers.getContractFactory(`NFTMinter`);

    squidBusNFT = await SquidBusNFT.attach(squidBusNFTAddress);
    squidPlayerNFT = await SquidPlayerNFT.attach(squidPlayerNFTAddress);
    game = await Game.attach(gameAddress);
    nftMinter = await NftMinter.attach(nftMinterAddress);

    console.log(`Add roles to contract`); //------------------------------------------------------------------------
    await squidBusNFT.grantRole(TOKEN_MINTER_ROLE, nftMinterAddress, {nonce: ++nonce, gasLimit: 3e6});
    await squidPlayerNFT.grantRole(TOKEN_MINTER_ROLE, nftMinterAddress, {nonce: ++nonce, gasLimit: 3e6});
    await squidPlayerNFT.grantRole(GAME_ROLE, gameAddress, {nonce: ++nonce, gasLimit: 3e6});

    console.log(`Setup withdrawal fee`);
    await game.setWithdrawalFee(decreaseWithdrawalFeeByDay, withdrawalFee, {nonce: ++nonce, gasLimit: 3e6});

    console.log('Setup SE divide');
    await squidPlayerNFT.setEnableSeDivide(enableSeDivide, seDivide, gracePeriod, {nonce: ++nonce, gasLimit: 3e6});

    console.log(`Add player contracts`);
    for(let i in playerContracts){
        await game.addPlayerContract(playerContracts[i], {nonce: ++nonce, gasLimit: 3e6});
        console.log(`Player contract ${playerContracts[i]} added`);
    }

    console.log(`Add games`);
    for(let i in games){
        await game.addNewGame(games[i], {nonce: ++nonce, gasLimit: 3e6})
        console.log(`New game # ${i} added`)
    }

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });