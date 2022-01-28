const { ethers, network } = require('hardhat')

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))


let deployer, squidPlayerNFT, claimer, bnft;
const tokenIds = require('../ids2.json').ids
const playerNFTAddress = `0xb00ED7E3671Af2675c551a1C26Ffdcc5b425359b`
const binanceNFTAddress = `0x1dDB2C0897daF18632662E71fdD2dbDC0eB3a9Ec`

const main = async() => {
    [deployer] = await ethers.getSigners();
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    const SquidPlayerNFT = await ethers.getContractFactory('SquidPlayerNFT')
    const BNFT = await ethers.getContractFactory('BNFT')
    const Claimer = await ethers.getContractFactory('NFTClaimer')


    bnft = BNFT.attach(binanceNFTAddress)
    squidPlayerNFT = SquidPlayerNFT.attach(playerNFTAddress)

    console.log('Deploy Claimer...')
    claimer = await Claimer.deploy(squidPlayerNFT.address, bnft.address, {nonce: ++nonce,gasLimit: 5e6})
    console.log('OK! Addr: ', claimer.address)


    console.log('await 10 sec...')
    await sleep(10000)
    console.log('OK!')

    console.log('claimer.recordSalt()...')
    await claimer.recordSalt({nonce: ++nonce,gasLimit: 5e6})
    console.log('OK!')

    console.log(`setup token Ids`)
    await claimer.setVouchersId(tokenIds.slice(0, 500 ),{nonce: ++nonce,gasLimit: 12e6}); console.log('setVouchersId (0 to 500)')
    await claimer.setVouchersId(tokenIds.slice(500,  1000),{nonce: ++nonce,gasLimit: 12e6}); console.log('setVouchersId (500, 1000)')
    await claimer.setVouchersId(tokenIds.slice(1000, 1500),{nonce: ++nonce,gasLimit: 12e6}); console.log('setVouchersId (1000, 1500)')
    await claimer.setVouchersId(tokenIds.slice(1500, 2000),{nonce: ++nonce,gasLimit: 12e6}); console.log('setVouchersId (1500, 2000)')


    console.log('grantRole...')
    const TOKEN_MINTER_ROLE = await squidPlayerNFT.TOKEN_MINTER_ROLE()
    await squidPlayerNFT.revokeRole(TOKEN_MINTER_ROLE, `0x85d24b0762087869aE0cae4A27B63c9933BdE40c`, {nonce: ++nonce,gasLimit: 5e6});
    await squidPlayerNFT.grantRole(TOKEN_MINTER_ROLE, claimer.address, {nonce: ++nonce,gasLimit: 5e6})
    console.log('OK!')


    console.log('Deployer address:', deployer.address)
    console.log('SquidPlayerNFT:', squidPlayerNFT.address)
    console.log('BNFT:', bnft.address)
    console.log('Claimer:', claimer.address)

}

main().then(() => process.exit(0)).catch( error => console.error(error) && process.exit(1))




