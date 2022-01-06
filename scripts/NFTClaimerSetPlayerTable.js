const { ethers, network } = require('hardhat')

let claimer;

const claimerAddress = `0xBf51f015BCa535980FdA01dc5c27980651107855`

const main = async() => {
    [deployer] = await ethers.getSigners();
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const Claimer = await ethers.getContractFactory('NFTClaimer')

    claimer = await Claimer.attach(claimerAddress);

    console.log(`Set player chance table`)
    let tx = await claimer.setPlayerChanceTable([[1,520,500,450], [2,1200,600,370],[3,1700,1300,120],[4,2300,1800,50],[5,3000,2400,10]], {nonce: ++nonce,gasLimit: 1e6});
    console.log(`Transaction status`, (await tx.wait()).status)

}


main().then(() => process.exit(0)).catch( error => console.error(error) && process.exit(1))




