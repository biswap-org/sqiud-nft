// npx hardhat run scripts/changeRewardTokens.js --network mainnetBSC
const { ethers, network } = require(`hardhat`);


const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const deployGameAddresses = require('./deployGameAddresses.json')

const gameAddress =deployGameAddresses.proxy_mainSquidGame

// Change BSW / WBNB payments (95% / 5%) with add BFG 10% decrease reward and 1,05 increase
const tokenRewards = {
    0:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(740,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(39,16), 0],
        [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(10, 18)]
    ],
    1:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(1542,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(81,16), 0]
    ],
    2:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(2355,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(124,16), 0]
    ],
    3:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(3178,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(167,16), 0],
        [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(25, 18)]
    ],
    4:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(4025,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(212,16), 0]
    ],
    5:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(4907,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(258,16), 0]
    ],
    6:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, toBN(5853,16), 0], //rewardTokens: [address, rewardInUSD, rewardInToken]
        [`0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c`, toBN(308,16), 0],
        [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(50, 18)]
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
