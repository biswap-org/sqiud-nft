//npx hardhat run scripts/updateGameParam0102.js --network mainnetBSC

const { ethers, network, upgrades} = require(`hardhat`);
const deployedContracts = require('./deployGameAddresses.json')

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const gameNFTAddress = deployedContracts.proxy_mainSquidGame;

let gameNft;
const holderPoolAddress = `0xa4b20183039b2F9881621C3A03732fBF0bfdff10`;

// $18.00 - 15 днів
// $34.2 - 30 днів
// $61.2 - 60 днів
const playerContracts = {
    0: [15*24*3600, toBN(18, 18), true], //15 days
    1: [30*24*3600, toBN(342, 17), true], //30 days
    2: [60*24*3600, toBN(612,17), true] //60 days
}

//1st game - 30 BSW
// 2nd game - 50 BSW
// 3rd game - 80 BSW
// 4th game - 100 BSW
// 5th game - 120 BSW
// 6th game - 150 BSW
// 7th game - 200 BSW
const games = {
    0: [
        //BSW-1378
        toBN(900, 18),  //minSeAmount
        toBN(30, 18),  //minStakeAmount
        8900, //chanceToWin; base 10000
    ],
    1:[
        toBN(2000, 18),  //minSeAmount
        toBN(50, 18),  //minStakeAmount
        8800, //chanceToWin; base 10000
    ],
    2:[
        toBN(3000, 18),  //minSeAmount
        toBN(80, 18),  //minStakeAmount
        8700, //chanceToWin; base 10000
    ],
    3:[
        toBN(4000, 18),  //minSeAmount
        toBN(100, 18),  //minStakeAmount
        8600, //chanceToWin; base 10000
    ],
    4:[
        toBN(5000, 18),  //minSeAmount
        toBN(120, 18),  //minStakeAmount
        8500, //chanceToWin; base 10000
    ],
    5:[
        toBN(6000, 18),  //minSeAmount
        toBN(150, 18),  //minStakeAmount
        8400, //chanceToWin; base 10000
    ],
    6:[
        toBN(7000, 18),  //minSeAmount
        toBN(200, 18),  //minStakeAmount
        8300, //chanceToWin; base 10000
    ]
}

async function getImplementationAddress(proxyAddress) {
    const implHex = await ethers.provider.getStorageAt(
        proxyAddress,
        "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    );
    return ethers.utils.hexStripZeros(implHex);
}

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;
    console.log(`nonce: ${+nonce}`);

    //Task BSW-1359
    console.log(`Start deploying upgrade Game NFT contract`);
    const GameNft = await ethers.getContractFactory(`MainSquidGame`);
    gameNft = await upgrades.upgradeProxy(gameNFTAddress, GameNft, {nonce: ++nonce, gasLimit: 3e6});
    await gameNft.deployed();
    console.log(`NFT game upgraded. New implementation address ${await getImplementationAddress(gameNFTAddress)}`);

    console.log(`Set holder pool in game`);
    gameNft = await GameNft.attach(gameNFTAddress);
    await gameNft.setAutoBsw(holderPoolAddress, {nonce: ++nonce, gasLimit: 3e6});

    //Task BSW-1401
    console.log(`Set new contract prices:`);
    for(let i in playerContracts){
        await gameNft.changePlayerContract(i, playerContracts[i], {nonce: ++nonce, gasLimit: 3e6});
        console.log(` - Player contract ${i} changed to ${playerContracts[i]}`);
    }

    //Task BSW-1379
    console.log(`Set Stake BSW Limit to play game:`);
    for(let i in games){
        await gameNft.setGameParameters(i, games[i][0], games[i][1], games[i][2], {nonce: ++nonce, gasLimit: 3e6})
        console.log(` - Game ${i} parameter changed`);
    }

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
