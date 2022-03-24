//npx hardhat run scripts/upgradeGameFiV2.js --network mainnetBSC
const { ethers, network, upgrades} = require(`hardhat`);

const deployedNFTContracts = require('./deployNFTAddresses.json')
const deployedGameContracts = require('./deployGameAddresses.json')

const gameNFTAddress = deployedGameContracts.proxy_mainSquidGame
const nftMinterAddress = deployedGameContracts.proxy_nftMinter
const playerNFTAddress = deployedNFTContracts.proxy_squidPlayerNFT

let playerNft, nftMinter, gameNft;

const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);
const toWei = n => ethers.BigNumber.from(10).pow(18).mul(n);

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const PlayerNft = await ethers.getContractFactory(`SquidPlayerNFT`);
    const GameNft = await ethers.getContractFactory(`MainSquidGame`);
    const NftMinter = await ethers.getContractFactory(`NFTMinter`);

    console.log(`Start deploying upgrade Player NFT contract`);
    playerNft = await upgrades.upgradeProxy(playerNFTAddress, PlayerNft, {nonce: ++nonce, gasLimit: 5e6});
    await playerNft.deployed();
    nonce++;
    console.log(`NFT player upgraded`);

    console.log(`Start deploying upgrade NFT game contract`);
    gameNft = await upgrades.upgradeProxy(gameNFTAddress, GameNft, {nonce: ++nonce, gasLimit: 5e6});
    await gameNft.deployed();
    nonce++;
    console.log(`NFT game upgraded`);

    console.log(`Start deploying upgrade NFT minter contract`);
    nftMinter = await upgrades.upgradeProxy(nftMinterAddress, NftMinter, {nonce: ++nonce, gasLimit: 5e6});
    await nftMinter.deployed();
    nonce++;
    console.log(`NFT minter upgraded`);

    playerNft = await PlayerNft.attach(playerNFTAddress);
    gameNft = await GameNft.attach(gameNFTAddress);
    nftMinter = await NftMinter.attach(nftMinterAddress);

    const playerContractsV2 = {
        0: [15*24*3600, toBN(375, 14), true], //15 days 0.0375 BSW
        1: [30*24*3600, toBN(7125, 13), true], //30 days 0.07125 BSW
    }

    console.log(`Set new contract V2 prices:`);
    for(let i in playerContractsV2){
        await gameNft.addPlayerContract(playerContractsV2[i], 2, {nonce: ++nonce, gasLimit: 3e6});
        console.log(` - Player contract ${i} changed to ${playerContractsV2[i]}`);
    }


    const gamesV2 = {
        0: [
            toWei(1000),  //minSeAmount
            toWei(30),  //minStakeAmount
            9900, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(731,16)], //rewardTokens: [address, rewardInUSD, rewardInToken]
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(30, 18)] //BFG
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
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(50, 18)] //BFG
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
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(75, 18)] //BFG
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
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(100, 18)] //BFG
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
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(130, 18)] //BFG
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
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(160, 18)] //BFG
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
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(190, 18)] //BFG
            ],
            `Rock-Paper-Scissors`, //game name
            true //Enabled
        ]
    }

    const gamesV1 = {
        0: [
            toWei(900),  //minSeAmount
            toWei(30),  //minStakeAmount
            8900, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(1142,16)],//BSW
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(20, 18)] //BFG
            ],
            `Destiny Marbles`, //game name
            true //Enabled
        ],
        1: [
            toWei(2000),  //minSeAmount
            toWei(50),  //minStakeAmount
            8800, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(2377,16)], //rewardTokens: [address, rewardInUSD, rewardInToken]
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(40, 18)] //BFG
            ],
            `Slippery Rope`, //game name
            true //Enabled
        ],
        2: [
            toWei(3000),  //minSeAmount
            toWei(80),  //minStakeAmount
            8700, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(3633,16)], //rewardTokens: [address, rewardInUSD, rewardInToken]
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(65, 18)] //BFG
            ],
            `Red Light, Blue Light`, //game name
            true //Enabled
        ],
        3: [
            toWei(4000),  //minSeAmount
            toWei(100),  //minStakeAmount
            8600, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(4902,16)], //rewardTokens: [address, rewardInUSD, rewardInToken]
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(90, 18)] //BFG
            ],
            `Flip-Flop Envelopes`, //game name
            true //Enabled
        ],
        4: [
            toWei(5000),  //minSeAmount
            toWei(120),  //minStakeAmount
            8500, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(6208,16)], //rewardTokens: [address, rewardInUSD, rewardInToken]
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(110, 18)] //BFG
            ],
            `Killing Sweets`, //game name
            true //Enabled
        ],
        5: [
            toWei(6000),  //minSeAmount
            toWei(150),  //minStakeAmount
            8400, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(7568,16)], //rewardTokens: [address, rewardInUSD, rewardInToken]
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(135, 18)] //BFG
            ],
            `Crowned Peak`, //game name
            true //Enabled
        ],
        6: [
            toWei(7000),  //minSeAmount
            toWei(200),  //minStakeAmount
            8300, //chanceToWin; base 10000
            [
                [`0x965f527d9159dce6288a2219db51fc6eef120dd1`, 0, toBN(9027,16)], //rewardTokens: [address, rewardInUSD, rewardInToken]
                [`0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`, 0, toBN(160, 18)] //BFG
            ],
            `Rock-Paper-Scissors`, //game name
            true //Enabled
        ]
    }


    console.log(`Add games V2`);
    for(let i in gamesV2){
        await gameNft.addNewGame(gamesV2[i], 2, {nonce: ++nonce, gasLimit: 3e6})
        console.log(`New game # ${i} added`)
    }
    console.log(`Done`)

    console.log(`Change gamesV1 parameters`);
    for(let i in gamesV1){
        await gameNft.setGameParameters(i, gamesV1[i], 1, {nonce: ++nonce, gasLimit: 3e6})
        console.log(`Game #${i} parameters changed`)
    }

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
