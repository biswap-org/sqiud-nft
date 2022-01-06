// npx hardhat run scripts/changeRewardTokens.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);


const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const deployGameAddresses = require('../deployGameAddresses.json')

const gameAddress =deployGameAddresses.proxy_mainSquidGame

// Change BSW / WBNB payments (85% / 15%)
const tokenRewards = {
    0:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(630,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(111,16), 0]
    ],
    1:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(1314,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(232,16), 0]
    ],
    2:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(2007,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(354,16), 0]
    ],
    3:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(2708,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(478,16), 0]
    ],
    4:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(3430,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(605,16), 0]
    ],
    5:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(4181,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(738,16), 0]
    ],
    6:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(4987,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(880,16), 0]
    ],

}

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;
    console.log(`nonce: ${+nonce}`);
    const Game = await ethers.getContractFactory(`MainSquidGame`);

    const game = await Game.attach(gameAddress);


    console.log(`Change token reward in games`);
    for(let i in tokenRewards){
        await game.setRewardTokensToGame(i,tokenRewards[i], {nonce: ++nonce, gasLimit: 3e6});
        console.log(`token rewards in Game #${+i+1} updated`);
    }

    console.log(`Done`)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
