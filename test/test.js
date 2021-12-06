const { expect } = require('chai')
const { ethers, upgrades, network } = require('hardhat')
const { loadFixture, deployContract, deployMockContract, MockProvider } = require('ethereum-waffle')
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

let accounts, owner, treasury;
let masterChef, oracle, autoBSW, nftMinter, mainSquidGame;
let USDT, BSW, squidBusNFT, squidPlayerNFT;
let TOKEN_MINTER_ROLE, GAME_ROLE, SE_BOOST_ROLE;


const BSW_price_in_USD = 1.5
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
const recoveryTime = 7
// const mainGamePriceInUSD = 100
const stakeAmountToPlay = 100

const GAS_REPORT = {}

before( async() => { 
    accounts = await ethers.getSigners()
    owner	 = accounts[0]
    treasury = accounts[1]

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
    await oracle.mock.consult.withArgs(USDT.address, toWei(500), BSW.address).returns( toWei(basicContractPriceInUSD  * BSW_price_in_USD))
    await oracle.mock.consult.withArgs(USDT.address, toWei(100), BSW.address).returns( toWei(stakeAmountToPlay  * BSW_price_in_USD))

    masterChef  = await deployMockContract(owner, require('../abisForFakes/MasterChefAbi.json'))
    autoBSW     = await deployMockContract(owner, require('../abisForFakes/PoolAutoBsw.json'))

    console.log('deployMockContract')
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
    console.log('MainSquidGame')
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
        TOKEN_MINTER_ROLE = await squidBusNFT.TOKEN_MINTER_ROLE()
        GAME_ROLE         = await squidPlayerNFT.GAME_ROLE()
        SE_BOOST_ROLE     = await squidPlayerNFT.SE_BOOST_ROLE()

        await squidBusNFT.grantRole(TOKEN_MINTER_ROLE, nftMinter.address)
        await squidPlayerNFT.grantRole(TOKEN_MINTER_ROLE, nftMinter.address)
        await squidPlayerNFT.grantRole(GAME_ROLE, mainSquidGame.address)
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
            // await expect(nftMinter.buyPlayer()).not.reverted
        }

        await expect(nftMinter.buyPlayer()).reverted
        expect((await nftMinter.getPlayerTokens(owner.address)).length).eq(await squidBusNFT.seatsInBuses(owner.address))
    })

    it('Should add PLAYER_CONTRACT into MAIN_SQUID_GAME', async() => {
        const playerContract = {
            duration: 86400 * 5, //5 days in sec
            priceInUSD: toWei(500),
            enable: true //true: enabled; false: disabled
        }

        const tx = await expect(mainSquidGame.addPlayerContract(playerContract)).not.reverted
        GAS_REPORT['mainSquidGame.addPlayerContract()'] = extractCost(await tx.wait())
        expect(await mainSquidGame.playerContracts(3)).eql([ethers.BigNumber.from(86400 * 5), toWei(500), true])
    })

    it('Should add GAME into MAIN_SQUID_GAME', async() => {
        const game = {
            minSeAmount: toWei(1000),
            minStakeAmount: toWei(100),
            chanceToWin: 5000,
            rewardTokens: [[BSW.address, toWei(100)], [USDT.address, toWei(100)]],
            name: 'Squid Game Numba One',
            enable: false
        }
        await mainSquidGame.addNewGame(game)
        const tx = await expect(mainSquidGame.addNewGame(game)).not.reverted
        GAS_REPORT['mainSquidGame.addNewGame()'] = extractCost(await tx.wait())
        expect(await mainSquidGame.games(0)).eql([
            toWei(1000), 
            toWei(100),
            ethers.BigNumber.from(5000), 
            // [[BSW.address, toWei(100)], [USDT.address, toWei(100)]],
            'Squid Game Numba One',
            false
        ])
    })

    it('Should buy CONTRACT for PLAYER_NFT', async() => {
        const ownerPlayers = await squidPlayerNFT['arrayUserPlayers(address)'](owner.address)
        const userIds = ownerPlayers.map(i => +i.tokenId)
        const contractPriceInUSD = (await mainSquidGame['playerContracts(uint256)'](3)).priceInUSD
        const contractPriceInBSW = await oracle.consult(USDT.address, contractPriceInUSD, BSW.address)

        await BSW.approve(mainSquidGame.address, contractPriceInBSW.mul(userIds.length))
        const tx = await expect(mainSquidGame.buyContracts(userIds, 3)).not.reverted
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
        console.table(playersRoundOne.map(p => { return{
                tokenId:                +p.tokenId,
                rarity:                 +p.rarity,         
                tokenOwner:             p.tokenOwner,        
                squidEnergy:            +p.squidEnergy/1e18,     
                maxSquidEnergy:         +p.maxSquidEnergy/1e18, 
                contractEndTimestamp:   +p.contractEndTimestamp,
                busyTo:                 +p.busyTo,        
                createTimestamp:        +p.createTimestamp,    
                uri:                    p.uri,                
            }
        }))
        let blockTimestamp = + ( await timeStampLastBlock() )

        playersRoundOne = playersRoundOne
            .filter( p => +p.contractEndTimestamp > blockTimestamp)
            .filter( p => +p.busyTo < blockTimestamp)


        const selectedPlayerIdsRoundOne = sortBySE(playersRoundOne, gameMinSeAmountToPlay).map(p => +p.tokenId)
        await expect(mainSquidGame.playGame(gameId, selectedPlayerIdsRoundOne), 'play r1 without stake').revertedWith('Need more stake in pools')

        await masterChef.mock.userInfo.withArgs(gameId, owner.address).returns(toWei(51), 0)
        await autoBSW.mock.userInfo.withArgs(owner.address).returns(toWei(49), 0, 0, 0)

        console.log(selectedPlayerIdsRoundOne)
      
        await expect(mainSquidGame.playGame(gameId, selectedPlayerIdsRoundOne), 'play r1 good').not.reverted
        await expect(mainSquidGame.playGame(gameId, selectedPlayerIdsRoundOne), 'play r1 busy tokens').revertedWith('Token already busy')

        blockTimestamp = + ( await timeStampLastBlock() )

        let playersRoundTwo = await nftMinter['getPlayerTokens(address)'](owner.address)
        playersRoundTwo = playersRoundTwo
            .filter( p => +p.contractEndTimestamp > blockTimestamp)
            .filter( p => +p.busyTo < blockTimestamp)

        const selectedPlayerIdsRoundTwo = sortBySE(playersRoundTwo, gameMinSeAmountToPlay).map(p => +p.tokenId)
        await mainSquidGame.playGame(gameId, selectedPlayerIdsRoundTwo)

    })

    it('GAS REPORT PRINT', async () => {
        console.table(GAS_REPORT)
    })
})