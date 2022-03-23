//npx hardhat run scripts/updateGameParam2303.js --network mainnetBSC

const { ethers, network } = require(`hardhat`);
const deployedContracts = require('./deployGameAddresses.json')

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

const gameNFTAddress = deployedContracts.proxy_mainSquidGame;

let gameNft;
//23032022
const tokenRewards = {
    0:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(1142,16)] //BSW
    ],
    1:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(2377,16)] //BSW
    ],
    2:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(3633,16)] //BSW
    ],
    3:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(4902,16)] //BSW
    ],
    4:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(6208,16)] //BSW
    ],
    5:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(7568,16)] //BSW
    ],
    6:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(9027,16)] //BSW
    ],

}

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;
    console.log(`nonce: ${+nonce}`);

    const GameNft = await ethers.getContractFactory(`MainSquidGame`);
    gameNft = await GameNft.attach(gameNFTAddress);


    //Task BSW-1644
    console.log(`Change token reward in games`);
    for(let i in tokenRewards){
        await gameNft.setRewardTokensToGame(i,tokenRewards[i], {nonce: ++nonce, gasLimit: 3e6});
        console.log(`token rewards in Game #${+i+1} updated`);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
