const { deployMockContract } = require('ethereum-waffle')
const { ethers, upgrades, network } = require('hardhat')
const { BigNumber } = require('ethers')
const { expect } = require('chai')


const toWei = n => ethers.BigNumber.from(10).pow(18).mul(n)

const extractCost = tx => {
    const GAS_SPENT = +tx.gasUsed
    const GAS_PRICE = 5e9
    const WEI_PRICE = 600/1e18

    const COST_BNB  = +(GAS_SPENT * GAS_PRICE / 1e18).toFixed(6)
    const COST_USD  = +(GAS_SPENT * GAS_PRICE * WEI_PRICE).toFixed(2)

    return {GAS_SPENT,COST_BNB,COST_USD}  
}

const GAS_REPORT = {}

before(async () => {
    accounts = await ethers.getSigners();
    owner = accounts[0];
    user = accounts[1];

    
    const Token = await ethers.getContractFactory('Token')
    BSW  = await Token.deploy('BSW',  'BSW',  toWei(1e6))
    USDT = await Token.deploy('USDT', 'USDT', toWei(1e6))
    
    oracle = await deployMockContract(owner, require('../abisForFakes/Oracle.json'))

    const SquidStaffGame = await ethers.getContractFactory('SquidStaffGame')
    squidStaffGame = await upgrades.deployProxy(SquidStaffGame, [owner.address, BSW.address, USDT.address, oracle.address])
})


describe('Check STUFF GAME contract', async () => {
    it('ADD GAME', async () => {
        const game  = {
            earlyWithdrawalFee:         5000, //fee take when user withdraw early time is end in base 10000
            priceInUSDT:                toWei(50), //in USDT
            listRewardTokens:           [BSW.address, USDT.address], //List reward tokens
            rewardTokensDistribution:   [10000, 10000], //Distribution of tokens in relation to the first token Base 10000
            enabled:                    true, //game is enable if true
        }

        const tx = await squidStaffGame.addGame(game)
        GAS_REPORT['squidStaffGame.addGame'] = extractCost(await tx.wait())

        // console.log((await squidStaffGame.getGames(owner.address))[0])
    })

    it('START NEW GAME', async () => {
        await oracle.mock.consult.withArgs(USDT.address, toWei(50), BSW.address).returns(toWei(50).mul(2))
        await BSW.approve(squidStaffGame.address, await oracle.consult(USDT.address, toWei(50), BSW.address))

        const tx = await squidStaffGame.startNewGame(0)
        GAS_REPORT['squidStaffGame.startNewGame'] = extractCost(await tx.wait())

        console.log(...(await squidStaffGame.pendingReward(owner.address, 0))[0])
        console.log(...(await squidStaffGame.pendingReward(owner.address, 0))[1])
        console.log((await squidStaffGame.getGames(owner.address))[1])
    })

    it('PENDING REWARD', async () => {
        let remainBlocks = +(await squidStaffGame.getGames(owner.address))[1][0].remainBlocks

        for (let i = 0; i < Math.min(3600, remainBlocks); i++) {
            if (i % 60 == 0){
                const rewards = (await squidStaffGame.pendingReward(owner.address, 0))[1]
                process.stdout.write(`${i}/${remainBlocks}\t${+(rewards[0]/1e18).toFixed(3)} \t ${+(rewards[1]/1e18).toFixed(3)}\r`)
            }
            console.log(await squidStaffGame.getGames(owner.address))
            expect(remainBlocks - i).eq(+(await squidStaffGame.getGames(owner.address))[1][0].remainBlocks)
            // expect(remainBlocks - i).eq(+(await squidStaffGame.getGames(owner.address))[1][0].remainBlocks)
            await network.provider.send('evm_mine')
        }
    })

    it('GAS REPORT PRINT', async () => {
        console.table(GAS_REPORT)
    })
})