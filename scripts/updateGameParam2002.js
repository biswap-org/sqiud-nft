//npx hardhat run scripts/updateGameParam2002.js --network mainnetBSC

const { ethers, network } = require(`hardhat`);
// const deployedContracts = require('./deployGameAddresses.json')

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);

// const gameNFTAddress = deployedContracts.proxy_mainSquidGame;
// const nftMinterAddress = deployedContracts.proxy_nftMinter;
const gameNFTAddress = `0xB08052D1EcD6Eb2Cafd2e829997d39a984B71eC0`;
const nftMinterAddress = `0x44F7D68e93ACEe685E6d554C967BE5Eb40b12b73`;

let gameNft, nftMinter;

const tokenRewards = {
    0:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(1478,16)], //BSW
        [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(10, 18)] //BFG
    ],
    1:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(3084,16)] //BSW
    ],
    2:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(4705,16)] //BSW
    ],
    3:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(6368,16)], //BSW
        [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(25, 18)]
    ],
    4:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(8052,16)] //BSW

    ],
    5:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(9821,16)] //BSW
    ],
    6:[
        [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(11705,16)], //BSW
        [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(50, 18)]
    ],

}

async function main() {
    let accounts = await ethers.getSigners();
    console.log(`Deployer address: ${ accounts[0].address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [accounts[0].address, "latest"]) - 1;
    console.log(`nonce: ${+nonce}`);

    const GameNft = await ethers.getContractFactory(`MainSquidGame`);
    gameNft = await GameNft.attach(gameNFTAddress);

    const NftMinter = await ethers.getContractFactory(`NFTMinter`);
    nftMinter = await NftMinter.attach(nftMinterAddress);

    //Task BSW-1543
    console.log(`Disable 60 days contracts`);
    await gameNft.changePlayerContract(2, [0, 0, false], {nonce: ++nonce, gasLimit: 3e6});
    console.log(`Player contract for 60 days disabled`);

    //Task BSW-1541
    console.log(`Change token reward in games`);
    for(let i in tokenRewards){
        await gameNft.setRewardTokensToGame(i,tokenRewards[i], {nonce: ++nonce, gasLimit: 3e6});
        console.log(`token rewards in Game #${+i+1} updated`);
    }

    //Task BSW-1542
    console.log(`Set limit to mint players`)
    await nftMinter.setPeriodLimitPlayers(500, true, {nonce: ++nonce, gasLimit: 3e6});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
