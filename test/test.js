const { expect } = require('chai')
const { ethers, upgrades, network } = require('hardhat')
const { deployMockContract } = require('ethereum-waffle')
const sortBySE = require('../scripts/sortPlayersBySquidEnergy').sortPlayersBySquidEnergyEfficent

const toWei = n => ethers.BigNumber.from(10).pow(18).mul(n)
const numberLastBlock = async () => (await ethers.provider.getBlock('latest')).number
const timeStampLastBlock = async () => (await ethers.provider.getBlock('latest')).timestamp
const extractCost = tx => {
    const GAS_SPENT = +tx.gasUsed
    const GAS_PRICE = 5e9
    const WEI_PRICE = 600/1e18

    const COST_BNB  = +(GAS_SPENT * GAS_PRICE / 1e18).toFixed(6)
    const COST_USD  = +(GAS_SPENT * GAS_PRICE * WEI_PRICE).toFixed(2)

    return {
        GAS_SPENT,
        COST_BNB,
        COST_USD
    }
}

let accounts, owner, treasury, subZero;
let masterChef, oracle, autoBSW, nftMinter, mainSquidGame;
let USDT, BSW, squidBusNFT, squidPlayerNFT;
let TOKEN_MINTER_ROLE, GAME_ROLE, SE_BOOST_ROLE, TOKEN_FREEZER_ROLE;


const BSW_price_in_USD = 1.5
const USDT_price_in_USD = 1
//squidBusNFT initialize parameters
const baseURIBusNFT = ``
const maxBusLevel = 5
const minBusBalance = 2
const maxBusBalance = 5
const busAdditionPeriod = 7 * 86400
//squidPlayerNFT initialize parameters
const baseURIPlayerNFT = ``
//NFTMinter initialize parameters
const busPriceInUSD = 1e12
const playerPriceInUSD = 1e12
const basicContractPriceInUSD = 500
//mainSuqidGame
const recoveryTime = 2 * 86400
// const mainGamePriceInUSD = 100
const stakeAmountToPlay = 100

const GAS_REPORT = {}

before( async() => { 
    accounts = await ethers.getSigners()
    owner       = accounts[0]
    treasury    = accounts[1]
    randomGuy   = accounts[2]
    subZero     = accounts[3]

    const Token = await ethers.getContractFactory('Token')
    USDT = await Token.deploy('USDT', 'USDT', toWei(1e6))
    BSW  = await Token.deploy('BSW',  'BSW',  toWei(1e6))


    const SquidBusNFT = await ethers.getContractFactory('SquidBusNFT')
    squidBusNFT = await upgrades.deployProxy(SquidBusNFT, [baseURIBusNFT, maxBusLevel, minBusBalance, maxBusBalance, busAdditionPeriod])

    const SquidPlayerNFT = await ethers.getContractFactory('SquidPlayerNFT')
    squidPlayerNFT = await upgrades.deployProxy(SquidPlayerNFT, [baseURIPlayerNFT])

    oracle = await deployMockContract(owner, require('../abisForFakes/Oracle.json'))
    await oracle.mock.consult.withArgs(USDT.address, busPriceInUSD, BSW.address).returns(busPriceInUSD * BSW_price_in_USD)
    await oracle.mock.consult.withArgs(USDT.address, playerPriceInUSD, BSW.address).returns(playerPriceInUSD * BSW_price_in_USD)
    await oracle.mock.consult.withArgs(USDT.address, toWei(500), BSW.address).returns( toWei(500  * BSW_price_in_USD))
    await oracle.mock.consult.withArgs(USDT.address, toWei(100), BSW.address).returns( toWei(100  * BSW_price_in_USD))
    await oracle.mock.consult.withArgs(USDT.address, toWei(50),  BSW.address).returns( toWei(50   * BSW_price_in_USD))
    await oracle.mock.consult.withArgs(USDT.address, toWei(200),  BSW.address).returns( toWei(200   * BSW_price_in_USD))
    await oracle.mock.consult.withArgs(USDT.address, toWei(20),  BSW.address).returns( toWei(20   * BSW_price_in_USD))
    await oracle.mock.consult.withArgs(USDT.address, toWei(20),  USDT.address).returns( toWei(20))

    masterChef  = await deployMockContract(owner, require('../abisForFakes/MasterChefAbi.json'))
    await masterChef.mock.userInfo.withArgs(0, owner.address).returns(toWei(51), 0)
    
    autoBSW     = await deployMockContract(owner, require('../abisForFakes/PoolAutoBsw.json'))
    await autoBSW.mock.userInfo.withArgs(owner.address).returns(0, 0,toWei(49), 0)

    const MainSquidGame = await ethers.getContractFactory('MainSquidGame')
    mainSquidGame = await upgrades.deployProxy(MainSquidGame,
        [
            USDT.address,
            BSW.address,
            squidBusNFT.address,
            squidPlayerNFT.address,
            oracle.address,
            masterChef.address,
            autoBSW.address,
            treasury.address,
            recoveryTime
        ]
    )

    await mainSquidGame.setWithdrawalFee(150, 2700)
    await squidPlayerNFT.setEnableSeDivide(false, 10000, 2592000)//30d

    const NftMinter = await ethers.getContractFactory('NFTMinter')
    nftMinter = await upgrades.deployProxy(NftMinter,
        [
            USDT.address,
            BSW.address,
            squidBusNFT.address,
            squidPlayerNFT.address,
            oracle.address,
            treasury.address,
            treasury.address,
            busPriceInUSD,
            playerPriceInUSD
        ])
})

describe('Check SquidGame main logic', async() => {
    it('Should be able to GRANT_ROLE', async () => {
        TOKEN_MINTER_ROLE  = await squidBusNFT.TOKEN_MINTER_ROLE()
        GAME_ROLE          = await squidPlayerNFT.GAME_ROLE()
        SE_BOOST_ROLE      = await squidPlayerNFT.SE_BOOST_ROLE()
        TOKEN_FREEZER_ROLE = await squidPlayerNFT.TOKEN_FREEZER()

        await squidBusNFT.grantRole(TOKEN_MINTER_ROLE, nftMinter.address)
        await squidPlayerNFT.grantRole(TOKEN_MINTER_ROLE, nftMinter.address)
        await squidPlayerNFT.grantRole(GAME_ROLE, mainSquidGame.address)
        await squidPlayerNFT.grantRole(TOKEN_FREEZER_ROLE, subZero.address)
    })

    it('Should buy first BUS_NFT', async() => {
        const busPriceInBSW = await oracle.consult(USDT.address, busPriceInUSD, BSW.address)
        const owners_BSW_balanceBefore  = await BSW.balanceOf(owner.address)
        const treaury_BSW_balanceBefore = await BSW.balanceOf(treasury.address)
        
        expect(await squidBusNFT.balanceOf(owner.address)).eq(0)
        await BSW.approve(nftMinter.address, busPriceInBSW)
        const tx = await expect(nftMinter.buyBus()).to.be.not.reverted
        GAS_REPORT['nftMinter.buyBus()'] = extractCost(await tx.wait())
        expect(await squidBusNFT.balanceOf(owner.address)).eq(1)
        expect(owners_BSW_balanceBefore.sub(await BSW.balanceOf(owner.address))).eq(busPriceInBSW)
        expect((await BSW.balanceOf(treasury.address)).sub(treaury_BSW_balanceBefore)).eq(busPriceInBSW)
    })

    it('Should buy first PLAYER_NFT', async() => {
        const playerPriceInBSW = await oracle.consult(USDT.address, playerPriceInUSD, BSW.address)
        const owners_BSW_balanceBefore  = await BSW.balanceOf(owner.address)
        const treaury_BSW_balanceBefore = await BSW.balanceOf(treasury.address)

        expect(await squidPlayerNFT.balanceOf(owner.address)).eq(0)
        await BSW.approve(nftMinter.address, playerPriceInBSW)

        const tx = await expect(nftMinter.buyPlayer()).to.be.not.reverted
        GAS_REPORT['nftMinter.buyPlayer()'] = extractCost(await tx.wait())

        expect(await squidPlayerNFT.balanceOf(owner.address)).eq(1)
        expect(owners_BSW_balanceBefore.sub(await BSW.balanceOf(owner.address))).eq(playerPriceInBSW)
        expect((await BSW.balanceOf(treasury.address)).sub(treaury_BSW_balanceBefore)).eq(playerPriceInBSW)
    })

    it('Should allow to burn BUS_NFT and PLAYER_NFT', async () => {
        expect(await squidBusNFT.ownerOf(1)).eq(owner.address)
        expect(await squidPlayerNFT.ownerOf(1)).eq(owner.address)

        tx = await expect(squidBusNFT.burn(1)).to.be.not.reverted
        GAS_REPORT['squidBusNFT.burn(id)'] = extractCost(await tx.wait())

        tx = await expect(squidPlayerNFT.burn(1)).to.be.not.reverted
        GAS_REPORT['squidPlayerNFT.burn(id)'] = extractCost(await tx.wait())

        await expect(squidBusNFT.ownerOf(1)).to.be.reverted
        await expect(squidPlayerNFT.ownerOf(1)).to.be.reverted

        expect(await nftMinter.getBusTokens(owner.address)).eql([])
        expect(await nftMinter.getPlayerTokens(owner.address)).eql([])
    })


    it('Should allow to buy minimal amount of BUS_NFT', async() => {
        const busPriceInBSW = await oracle.consult(USDT.address, busPriceInUSD, BSW.address)
        expect(await squidBusNFT.balanceOf(owner.address)).eq(0)
       
        for (let i = 0; i < minBusBalance ; i++) {
            await BSW.approve(nftMinter.address, busPriceInBSW)
            await expect(nftMinter.buyBus()).not.reverted
        }

        expect(await squidBusNFT.balanceOf(owner.address)).eq(minBusBalance)
    })

    it('Should allow to buy additional BUS_NFT each 7 days untill max BUS_NFT amount reached', async() => {
        const busPriceInBSW = await oracle.consult(USDT.address, busPriceInUSD, BSW.address)
        expect(await squidBusNFT.balanceOf(owner.address)).eq(minBusBalance)

        await BSW.approve(nftMinter.address, busPriceInBSW)
        await expect(nftMinter.buyBus()).reverted

        for (let i = minBusBalance; i < maxBusBalance; i++) {
            await network.provider.send("evm_increaseTime", [86400 * 7])
            await network.provider.send("evm_mine")
            await BSW.approve(nftMinter.address, busPriceInBSW)
            await expect(nftMinter.buyBus()).not.reverted
            expect(await squidBusNFT.allowedBusBalance(owner.address)).eq(i + 1)
        }

        await BSW.approve(nftMinter.address, busPriceInBSW)
        await expect(nftMinter.buyBus()).reverted

        expect(await squidBusNFT.allowedBusBalance(owner.address)).eq(maxBusBalance)
    })    

    it('Should allow to buy PLAYER_NFT according to available seats', async() => {
        const playerPriceInBSW = await oracle.consult(USDT.address, playerPriceInUSD, BSW.address)
        const countOfSeatsBefore = await squidBusNFT.seatsInBuses(owner.address)
        const levelOfDestoyableBus = +(await squidBusNFT.getToken(3)).level
        await expect(squidBusNFT.burn(3), 'Should burn BUS NFT with id 3').not.reverted
        const countOfSeatsAfter = await squidBusNFT.seatsInBuses(owner.address)
        expect(countOfSeatsAfter).eq(countOfSeatsBefore.sub(levelOfDestoyableBus))

        for (let i = 0; i < countOfSeatsAfter; i++) {
            await BSW.approve(nftMinter.address, playerPriceInBSW)
            nftMinter.buyPlayer()
        }

        await expect(nftMinter.buyPlayer()).reverted
        expect((await nftMinter.getPlayerTokens(owner.address)).length).eq(await squidBusNFT.seatsInBuses(owner.address))
    })

    it('Should add PLAYER_CONTRACT into MAIN_SQUID_GAME', async() => {
        const playerContract = {
            duration: 86400 * 5,
            priceInUSD: toWei(500),
            enable: true
        }
        const tx = await expect(mainSquidGame.addPlayerContract(playerContract)).not.reverted
        GAS_REPORT['mainSquidGame.addPlayerContract()'] = extractCost(await tx.wait())
        expect(await mainSquidGame.playerContracts(0)).eql([ethers.BigNumber.from(86400 * 5).toNumber(), toWei(500), true])
    })

    it('Should add GAME into MAIN_SQUID_GAME', async() => {
        const game = {
            minSeAmount: toWei(1000),
            minStakeAmount: toWei(100),
            chanceToWin: 10000,
            rewardTokens: [[BSW.address, toWei(50), toWei(0)], [USDT.address, toWei(200), toWei(200)]],
            name: 'Squid Game Numba One',
            enable: false
        }

        await mainSquidGame.addNewGame(game)
        const tx = await expect(mainSquidGame.addNewGame(game)).not.reverted
        GAS_REPORT['mainSquidGame.addNewGame()'] = extractCost(await tx.wait())
        expect(await mainSquidGame.games(0)).eql([
            toWei(1000), 
            toWei(100),
            ethers.BigNumber.from(10000), 
            // [[BSW.address, toWei(100)], [USDT.address, toWei(100)]],
            'Squid Game Numba One',
            false
        ])
    })

    it('Should change GAME REWARD TOKENS', async() => {
        const tx = await mainSquidGame.setRewardTokensToGame(0, [[BSW.address, toWei(0), toWei(100)], [USDT.address, toWei(0), toWei(100)]])
        GAS_REPORT['mainSquidGame.setRewardTokensToGame()'] = extractCost(await tx.wait())

        const answer = await mainSquidGame.getGameInfo(owner.address)
        await expect(answer[0][1][3]).eql([[BSW.address, toWei(0), toWei(100)], [USDT.address, toWei(0), toWei(100)]])
    })

    it('Should buy CONTRACT for PLAYER_NFT', async() => { 
        const ownerPlayers = await squidPlayerNFT['arrayUserPlayers(address)'](owner.address)
        const userIds = ownerPlayers.map(i => +i.tokenId)
        const contractPriceInUSD = (await mainSquidGame['playerContracts(uint256)'](0)).priceInUSD
        const contractPriceInBSW = await oracle.consult(USDT.address, contractPriceInUSD, BSW.address)

        await BSW.approve(mainSquidGame.address, contractPriceInBSW.mul(userIds.length))
        const tx = await expect(mainSquidGame.buyContracts(userIds, 0)).not.reverted
        GAS_REPORT[`mainSquidGame.buyContracts() for ${userIds.length} NFT`] = extractCost(await tx.wait())

        //TODO check all views for correct output
    })

    it('Should ENABLE and START a GAME', async() => {
        const gameId = 0
        const gameMinSeAmountToPlay = (await mainSquidGame.games(gameId)).minSeAmount
        await mainSquidGame.enableGame(gameId)

        await masterChef.mock.userInfo.withArgs(gameId, owner.address).returns(0, 0)
        await autoBSW.mock.userInfo.withArgs(owner.address).returns(0, 0, 0, 0)

        let playersRoundOne = await nftMinter['getPlayerTokens(address)'](owner.address)
        let blockTimestamp = + ( await timeStampLastBlock() )

        playersRoundOne = playersRoundOne
            .filter( p => +p.contractEndTimestamp > blockTimestamp)
            .filter( p => +p.busyTo < blockTimestamp)


        const selectedPlayerIdsRoundOne = sortBySE(playersRoundOne, gameMinSeAmountToPlay).map(p => +p.tokenId)
        await expect(mainSquidGame.playGame(gameId, selectedPlayerIdsRoundOne), 'play r1 without stake').revertedWith('Need more stake in pools')

        await masterChef.mock.userInfo.withArgs(gameId, owner.address).returns(toWei(51), 0)
        await autoBSW.mock.userInfo.withArgs(owner.address).returns(0, 0,toWei(49), 0)

        const tx = await expect(mainSquidGame.playGame(gameId, selectedPlayerIdsRoundOne), 'play r1 good').not.reverted
        GAS_REPORT[`mainSquidGame.playGame() for ${selectedPlayerIdsRoundOne.length} NFT`] = extractCost(await tx.wait())
        await expect(mainSquidGame.playGame(gameId, selectedPlayerIdsRoundOne), 'play r1 busy tokens').revertedWith('Token already busy')

        blockTimestamp = + ( await timeStampLastBlock() )

        let playersRoundTwo = await nftMinter['getPlayerTokens(address)'](owner.address)
        playersRoundTwo = playersRoundTwo
            .filter( p => +p.contractEndTimestamp > blockTimestamp)
            .filter( p => +p.busyTo < blockTimestamp)

        const selectedPlayerIdsRoundTwo = sortBySE(playersRoundTwo, gameMinSeAmountToPlay).map(p => +p.tokenId)

        await mainSquidGame.playGame(gameId, selectedPlayerIdsRoundTwo)

        let playersAfter = await nftMinter['getPlayerTokens(address)'](owner.address)
    })

    it('Should properly use random number in functions', async () => {
        const rewards = {
            BSW: {
                USD: toWei(20),
                TOKEN: toWei(0)
            },
            USDT: {
                USD: toWei(0),
                TOKEN: toWei(1)
            }
        }

        await mainSquidGame.addNewGame({
            minSeAmount: toWei(100),
            minStakeAmount: toWei(100),
            chanceToWin: 9999,//99.99%
            rewardTokens: [[BSW.address, rewards.BSW.USD, rewards.BSW.TOKEN], [USDT.address, rewards.USDT.USD, rewards.USDT.TOKEN]],
            name: 'TEST RANDOM',
            enable: true
        })

        await mainSquidGame.addPlayerContract({
            duration: 86400 * 10000,
            priceInUSD: toWei(0),
            enable: true
        })

        const gameId = +await mainSquidGame.getGameCount() - 1

        BSW.connect(owner).transfer(randomGuy.address, toWei(1000))
        USDT.connect(owner).transfer(randomGuy.address, toWei(1000))

        const busPriceInBSW = await oracle.consult(USDT.address, busPriceInUSD, BSW.address)
        await BSW.connect(randomGuy).approve(nftMinter.address, busPriceInBSW)
        await nftMinter.connect(randomGuy).buyBus()

        const playerPriceInBSW = await oracle.consult(USDT.address, playerPriceInUSD, BSW.address)
        await BSW.connect(randomGuy).approve(nftMinter.address, playerPriceInBSW)
        await nftMinter.connect(randomGuy).buyPlayer()

        const randomGuyPlayers = await squidPlayerNFT['arrayUserPlayers(address)'](randomGuy.address)
        const contractPriceInUSD = (await mainSquidGame['playerContracts(uint256)'](1)).priceInUSD

        await oracle.mock.consult.withArgs(USDT.address, contractPriceInUSD, BSW.address).returns(contractPriceInUSD * BSW_price_in_USD)
        const contractPriceInBSW = await oracle.consult(USDT.address, contractPriceInUSD, BSW.address)


        const userIds = randomGuyPlayers.map(i => +i.tokenId)
        await BSW.approve(mainSquidGame.address, contractPriceInBSW)
        const tx = await expect(mainSquidGame.connect(randomGuy).buyContracts(userIds, 1)).not.reverted
        GAS_REPORT[`mainSquidGame.buyContracts()[2] for random guy's player`] = extractCost(await tx.wait())

        await masterChef.mock.userInfo.withArgs(0, randomGuy.address).returns(toWei(51), 0)
        await autoBSW.mock.userInfo.withArgs(randomGuy.address).returns(0, 0,toWei(49), 0)

        let runs = 100
        let wins = 0

        for (let i = 0; i < runs; i++){
            await network.provider.send("evm_increaseTime", [86400 * 10])
            await network.provider.send("evm_mine")
            const responce = await( await mainSquidGame.connect(randomGuy).playGame(gameId, userIds) ).wait()
            const isWIn = responce.events.filter( e => e.event === 'GamePlay').map( gp => gp.args.userWin)[0]
            isWIn && wins++
            process.stdout.write(`${wins}/${runs} : ${(wins/(i+1)*100).toFixed(2)}% => 99.99%\r`)
        }

        expect(await mainSquidGame.getUserRewardBalances(randomGuy.address)).eql(
            [
                [BSW.address, USDT.address],
                [
                    rewards.BSW.TOKEN.mul(wins).add(rewards.BSW.USD.mul(wins * (2 * BSW_price_in_USD)).div(2)),
                    rewards.USDT.TOKEN.mul(wins).add(rewards.USDT.USD.mul(wins * (2 * USDT_price_in_USD)).div(2)),
                ]
            ])

        console.log(`${wins}/${runs} rounds winned, while win chance is 99.99%`)
    })

    it('Should correctly payout winned tokens', async() => {
        BSW.transfer(mainSquidGame.address, toWei(1000))
        USDT.transfer(mainSquidGame.address, toWei(1000))
        const tokensToPayout = await mainSquidGame.getUserRewardBalances(owner.address)

        const before = {}
        before.player = {}
        before.player.BSW  = await BSW.balanceOf(owner.address)
        before.player.USDT = await USDT.balanceOf(owner.address)

        before.game = {}
        before.game.BSW  = await BSW.balanceOf(mainSquidGame.address)
        before.game.USDT = await USDT.balanceOf(mainSquidGame.address)

        await mainSquidGame.withdrawReward()

        const after = {}
        after.player = {}
        after.player.BSW   = await BSW.balanceOf(owner.address)
        after.player.USDT  = await USDT.balanceOf(owner.address)

        after.game = {}
        after.game.BSW   = await BSW.balanceOf(mainSquidGame.address)
        after.game.USDT  = await USDT.balanceOf(mainSquidGame.address)

        expect(before.player.BSW.add(tokensToPayout[1][0])).eq(after.player.BSW)
        expect(before.player.USDT.add(tokensToPayout[1][1])).eq(after.player.USDT)

        expect(before.game.BSW.sub(tokensToPayout[1][0])).eq(after.game.BSW)
        expect(before.game.USDT.sub(tokensToPayout[1][1])).eq(after.game.USDT)
    })

    it('Should correctly reduse withdraw fee each period and reduce SE after GRACE_PERIOD', async() => {
        await squidPlayerNFT.setEnableSeDivide(true, 5000, 2592000)

        const decreaseWithdrawalFeeByDay =  +await mainSquidGame.decreaseWithdrawalFeeByDay()//2700
        const withdrawalFee =               +await mainSquidGame.withdrawalFee()//150
        const recoveryTime =                +await mainSquidGame.recoveryTime()//2d
        const gracePeriod =                 +await squidPlayerNFT.gracePeriod()//30d

        const gameId =              +await mainSquidGame.getGameCount() - 1
        const busPriceInBSW =       await oracle.consult(USDT.address, busPriceInUSD, BSW.address)
        const playerPriceInBSW =    await oracle.consult(USDT.address, playerPriceInUSD, BSW.address)
        const contractPriceInBSW =  await oracle.consult(USDT.address, 0, BSW.address)

        await BSW.approve(nftMinter.address, playerPriceInBSW.add(busPriceInBSW).add(contractPriceInBSW))
        await nftMinter.buyBus()
        await nftMinter.buyPlayer()

        const players = await squidPlayerNFT['arrayUserPlayers(address)'](owner.address)
        const playerId = +players[players.length -1].tokenId
        await mainSquidGame.buyContracts([playerId], 1)

        const initialSE = (await squidPlayerNFT.getToken(playerId)).squidEnergy

        const before = {
            player:{   BSW: await BSW.balanceOf(owner.address),           USDT: await USDT.balanceOf(owner.address)},
            game:{     BSW: await BSW.balanceOf(mainSquidGame.address),   USDT: await USDT.balanceOf(mainSquidGame.address)},
            treasury: {BSW: await BSW.balanceOf(treasury.address),        USDT: await USDT.balanceOf(treasury.address)}
        }
        await mainSquidGame.playGame(gameId, [playerId])

        await network.provider.send("evm_increaseTime", [86400 * Math.trunc(Math.random() * 21)])
        await network.provider.send("evm_mine")
        
        
        const tokensToPayout = await mainSquidGame.getUserRewardBalances(owner.address)
        const timePassed = +(await timeStampLastBlock()) - +await mainSquidGame.withdrawTimeLock(owner.address)//~0
        let decrease = Math.trunc(timePassed / 86400) * decreaseWithdrawalFeeByDay
        let fee = withdrawalFee - Math.min(withdrawalFee, decrease) 

        await mainSquidGame.withdrawReward()

        const after = {
            player:{   BSW: await BSW.balanceOf(owner.address),           USDT: await USDT.balanceOf(owner.address)},
            game:{     BSW: await BSW.balanceOf(mainSquidGame.address),   USDT: await USDT.balanceOf(mainSquidGame.address)},
            treasury: {BSW: await BSW.balanceOf(treasury.address),        USDT: await USDT.balanceOf(treasury.address)}
        }
        const tokensToPayoutAfter = await mainSquidGame.getUserRewardBalances(owner.address)
        expect(tokensToPayoutAfter[1].map(t => +t)).eql([0,0])

        expect(before.player.BSW. add(tokensToPayout[1][0].mul(10000 - fee).div(10000))).eq(after.player.BSW)
        expect(before.player.USDT.add(tokensToPayout[1][1].mul(10000 - fee).div(10000))).eq(after.player.USDT)

        expect(before.game.BSW. sub(tokensToPayout[1][0])).eq(after.game.BSW)
        expect(before.game.USDT.sub(tokensToPayout[1][1])).eq(after.game.USDT)

        expect(before.treasury.BSW. add(tokensToPayout[1][0].mul(fee).div(10000))).eq(after.treasury.BSW)
        expect(before.treasury.USDT.add(tokensToPayout[1][1].mul(fee).div(10000))).eq(after.treasury.USDT)

        await network.provider.send("evm_increaseTime", [gracePeriod])
        await network.provider.send("evm_mine")

        await mainSquidGame.playGame(gameId, [playerId])
        expect((await squidPlayerNFT.getToken(playerId)).squidEnergy ).eq(initialSE.div(2))
    })

    it('Should block operations with frozen tokens', async () => {
        const contractPriceInBSW = await oracle.consult(USDT.address, 0, BSW.address)
        await BSW.approve(mainSquidGame.address, contractPriceInBSW)

        const players = await squidPlayerNFT['arrayUserPlayers(address)'](owner.address)
        const playerIds = players.map(i => +i.tokenId)
        for (let i = 0; i < playerIds.length; i++)  await squidPlayerNFT.connect(subZero).tokenFreeze(playerIds[i])
        
        await squidPlayerNFT.setApprovalForAll(randomGuy.address, true)
        
        await expect(mainSquidGame.buyContracts([playerIds[0]], 1)).revertedWith('Token frozen')
        await expect(mainSquidGame.playGame(2, [playerIds[0]])).revertedWith('Token frozen')
        await expect(squidPlayerNFT.approve(randomGuy.address, [playerIds[0]])).revertedWith('Token frozen')
        await expect(squidPlayerNFT.transferFrom(owner.address, randomGuy.address, playerIds[0])).revertedWith('Token frozen')   
        await expect(squidPlayerNFT.burn(playerIds[0])).revertedWith('Token frozen')
    })

    it('Should disallow to start game with enemy player', async () => {
        const gameId = +await mainSquidGame.getGameCount() - 1
        const players = await squidPlayerNFT['arrayUserPlayers(address)'](randomGuy.address)
        const playerId = + players[players.length -1].tokenId
        const contractPriceInBSW = await oracle.consult(USDT.address, 0, BSW.address)

        await BSW.approve(mainSquidGame.address, contractPriceInBSW)
        await expect(mainSquidGame.buyContracts([playerId], 1)).reverted
        await expect(mainSquidGame.playGame(gameId, [playerId])).reverted
    })

    it('GAS REPORT PRINT', async () => {
        console.table(GAS_REPORT)
    })
})
