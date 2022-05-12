//npx hardhat run scripts/updateGameFiV2GamesParameters.js --network mainnetBSC
const { ethers, network, upgrades} = require(`hardhat`);

const deployedGameContracts = require('./deployGameAddresses.json')

const gameNFTAddress = deployedGameContracts.proxy_mainSquidGame

let gameNft;

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);
const toWei = n => ethers.BigNumber.from(10).pow(18).mul(n);

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const GameNft = await ethers.getContractFactory(`MainSquidGame`);

    gameNft = await GameNft.attach(gameNFTAddress);


    const gamesV1 = {
        0: [
            toWei(900),  //minSeAmount
            toWei(30),  //minStakeAmount
            8900, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(1648,16)]//BSW
            ],
            `Destiny Marbles`, //game name
            true //Enabled
        ],
        1: [
            toWei(2000),  //minSeAmount
            toWei(50),  //minStakeAmount
            8800, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(3433,16)] //rewardTokens: [address, rewardInUSD, rewardInToken]
            ],
            `Slippery Rope`, //game name
            true //Enabled
        ],
        2: [
            toWei(3000),  //minSeAmount
            toWei(80),  //minStakeAmount
            8700, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(5246,16)] //rewardTokens: [address, rewardInUSD, rewardInToken]
            ],
            `Red Light, Blue Light`, //game name
            true //Enabled
        ],
        3: [
            toWei(4000),  //minSeAmount
            toWei(100),  //minStakeAmount
            8600, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(7080,16)] //rewardTokens: [address, rewardInUSD, rewardInToken]
            ],
            `Flip-Flop Envelopes`, //game name
            true //Enabled
        ],
        4: [
            toWei(5000),  //minSeAmount
            toWei(120),  //minStakeAmount
            8500, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(8966,16)] //rewardTokens: [address, rewardInUSD, rewardInToken]
            ],
            `Killing Sweets`, //game name
            true //Enabled
        ],
        5: [
            toWei(6000),  //minSeAmount
            toWei(150),  //minStakeAmount
            8400, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(10931,16)] //rewardTokens: [address, rewardInUSD, rewardInToken]
            ],
            `Crowned Peak`, //game name
            true //Enabled
        ],
        6: [
            toWei(7000),  //minSeAmount
            toWei(200),  //minStakeAmount
            8300, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(13037,16)] //rewardTokens: [address, rewardInUSD, rewardInToken]
            ],
            `Rock-Paper-Scissors`, //game name
            true //Enabled
        ]
    }

    const gamesV2 = {
        0: [
            toWei(1000),  //minSeAmount
            toWei(30),  //minStakeAmount
            9900, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(731,16)], //rewardTokens: [address, rewardInUSD, rewardInToken]
            ],
            `Destiny Marbles`, //game name
            true //Enabled
        ],
        1: [
            toWei(2000),  //minSeAmount
            toWei(50),  //minStakeAmount
            9800, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(1371,16)],
            ],
            `Slippery Rope`, //game name
            true //Enabled
        ],
        2: [
            toWei(3000),  //minSeAmount
            toWei(80),  //minStakeAmount
            9700, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(2028,16)],
            ],
            `Red Light, Blue Light`, //game name
            true //Enabled
        ],
        3: [
            toWei(4000),  //minSeAmount
            toWei(100),  //minStakeAmount
            9600, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(2706,16)],
            ],
            `Flip-Flop Envelopes`, //game name
            true //Enabled
        ],
        4: [
            toWei(5000),  //minSeAmount
            toWei(120),  //minStakeAmount
            9500, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(3416,16)],
            ],
            `Killing Sweets`, //game name
            true //Enabled
        ],
        5: [
            toWei(6000),  //minSeAmount
            toWei(150),  //minStakeAmount
            9400, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(4157,16)],
            ],
            `Crowned Peak`, //game name
            true //Enabled
        ],
        6: [
            toWei(7000),  //minSeAmount
            toWei(200),  //minStakeAmount
            9300, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(4920,16)],
            ],
            `Rock-Paper-Scissors`, //game name
            true //Enabled
        ]
    }


    console.log(`Change gamesV2 parameters`);
    for(let i in gamesV1){
        await gameNft.setGameParameters(i, gamesV1[i], 1, {nonce: ++nonce, gasLimit: 3e6})
        console.log(`Game #${i} parameters changed`)
    }
    console.log(`Done`)

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
