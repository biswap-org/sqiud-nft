//npx hardhat run scripts/deploySquidWorkerGame.js --network mainnetBSC

const { ethers, upgrades } = require(`hardhat`);


const fs = require('fs')


const toBN = (numb, power) =>  ethers.BigNumber.from(10).pow(power).mul(numb);


//game initialize parameters
const treasuryAddress = `0x162d6FC25AD9da8eE117Dc9333E66DFD7C40b9eA`
const bswTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`
const autoBswAddress = `0xa4b20183039b2F9881621C3A03732fBF0bfdff10`
const oracleAddress = `0x2f48cde4cfd0fb4f5c873291d5cf2dc9e61f2db0`
const price = toBN(25,18)
const minStakeAmount = toBN(10,18)
const earlyWithdrawalFee = 500
const maxWorkersPerUser = 2

let squidWorkerGame


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

    const SquidWorkerGame = await ethers.getContractFactory(`SquidWorkerGame`);

    console.log(`Start deploying Workers game contract`);
    squidWorkerGame = await upgrades.deployProxy(
        SquidWorkerGame,
        [
            treasuryAddress,
            bswTokenAddress,
            autoBswAddress,
            oracleAddress,
            price,
            minStakeAmount,
            earlyWithdrawalFee,
            maxWorkersPerUser
        ],
    );
    await squidWorkerGame.deployed();
    const weeks = [
        2730,
        2731,
        2732,
        2733,
        2734,
        2735,
        2736,
        2737,
        2738,
        2739,
        2740,
        2741,
        2742,
        2743,
        2744,
        2745,
        2746,
        2747,
        2748,
        2749,
        2750,
        2751,
        2752,
        2753,
        2754,
        2755,
        2756,
        2757,
        2758,
        2759,
        2760,
        2761,
        2762,
        2763,
        2764,
        2765,
        2766,
        2767,
        2768,
        2769,
        2770,
        2771,
        2772,
        2773,
        2774,
        2775,
        2776,
        2777
    ]
    const limits = [
        5000,
        5000,
        4000,
        4000,
        3000,
        3000,
        2000,
        2000,
        2000,
        2000,
        1000,
        1000,
        1000,
        1000,
        500,
        500,
        500,
        500,
        500,
        500,
        500,
        500,
        500,
        500,
        500,
        500,
        500,
        500,
        500,
        500,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250,
        250
    ]
    await squidWorkerGame.setWeeklyWorkersLimit(weeks, limits, {gasLimit: 3e6})

    const deployedContracts = {
        deployTime:     new Date().toLocaleString(),
        proxy_staffWorkGame:  squidWorkerGame.address,
        imp_staffWorkGame:  await getImplementationAddress(squidWorkerGame.address),
    }
    fs.writeFileSync('deployWorkerGameAddresses.json', JSON.stringify(deployedContracts, null, 4), () => {
        console.log(deployedContracts)
    })
        console.log(deployedContracts)

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
