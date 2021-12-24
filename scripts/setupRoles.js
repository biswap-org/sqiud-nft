const { ethers, network, upgrades } = require(`hardhat`);
const {BigNumber} = require("ethers");

const toWei = n => ethers.BigNumber.from(10).pow(18).mul(n);
const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const deployNFTAddresses = require('./deployNFTAddresses.json')
const deployGameAddresses = require('./deployGameAddresses.json')

const squidBusNFTAddress    = deployNFTAddresses.proxy_squidBusNFT
const squidPlayerNFTAddress = deployNFTAddresses.proxy_squidPlayerNFT
const gameAddress           = deployGameAddresses.proxy_mainSquidGame
const nftMinterAddress      = deployGameAddresses.proxy_nftMinter

let squidBusNFT, squidPlayerNFT, game, nftMinter

const TOKEN_MINTER_ROLE     = `0x262c70cb68844873654dc54487b634cb00850c1e13c785cd0d96a2b89b829472`;
const GAME_ROLE             = `0x6a64baf327d646d1bca72653e2a075d15fd6ac6d8cbd7f6ee03fc55875e0fa88`;
const SE_BOOST_ROLE         = `0xfca6bac8781bc66ef196bb85acbfc743e952d50480437ed109b46e883bda687b`;
const DEFAULT_ADMIN_ROLE    = `0x0000000000000000000000000000000000000000000000000000000000000000`;

//Game parameters
const decreaseWithdrawalFeeByDay = 150 //withdrawalFee decrease on 1,5% by day
const withdrawalFee = 2700 //Initial fee 27%

//PlayerNFT Parameters
const enableSeDivide = true //Enabled
const seDivide = 100 // 1% by game
const gracePeriod =  45*3600*24 //45 days

//Mint contract parameters
const playerLimit = 2000; // Count players per 6 hours
const enabledLimitMintPlayer = true;

const playerContracts = {
    1: [15*24*3600, toBN(15, 18), true], //15 days
    2: [30*24*3600, toBN(285, 17), true], //30 days
    3: [60*24*3600, toBN(51,18),true] //60 days
}


const games = {
    1: [
        toWei(900),  //minSeAmount
        toWei(20),  //minStakeAmount
        8900, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(519,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
            [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(222,16), 0]
        ],
        `Destiny Marbles`, //game name
        true //Enabled
    ],
    2: [
        toWei(2000),  //minSeAmount
        toWei(30),  //minStakeAmount
        8800, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(1082,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
            [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(464,16), 0]
        ],
        `Slippery Rope`, //game name
        true //Enabled
    ],
    3: [
        toWei(3000),  //minSeAmount
        toWei(40),  //minStakeAmount
        8700, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(1653,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
            [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(708,16), 0]
        ],
        `Red Light, Blue Light`, //game name
        true //Enabled
    ],
    4: [
        toWei(4000),  //minSeAmount
        toWei(50),  //minStakeAmount
        8600, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(2230,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
            [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(956,16), 0]
        ],
        `Flip-Flop Envelopes`, //game name
        true //Enabled
    ],
    5: [
        toWei(5000),  //minSeAmount
        toWei(60),  //minStakeAmount
        8500, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(2825,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
            [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(1211,16), 0]
        ],
        `Killing Sweets`, //game name
        true //Enabled
    ],
    6: [
        toWei(6000),  //minSeAmount
        toWei(70),  //minStakeAmount
        8400, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(3443,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
            [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(1476,16), 0]
        ],
        `Crowned Peak`, //game name
        true //Enabled
    ],
    7: [
        toWei(7000),  //minSeAmount
        toWei(80),  //minStakeAmount
        8300, //chanceToWin; base 10000
        [
            [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(4107,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
            [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(1760,16), 0]
        ],
        `Rock-Paper-Scissors`, //game name
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

    console.log('Setup mint player limits by period');
    await nftMinter.setPeriodLimitPlayers(playerLimit, enabledLimitMintPlayer);

    console.log('Setup SE divide');
    await squidPlayerNFT.setSeDivide(enableSeDivide, seDivide, gracePeriod, {nonce: ++nonce, gasLimit: 3e6});

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

    console.log(`Done`)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });