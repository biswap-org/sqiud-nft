const { expect } = require(`chai`);
const { ethers, upgrades, network } = require(`hardhat`);
const {BigNumber} = require("ethers");

const TOKEN_LAUNCHPAD_MINTER = "0x7121fcd3dfef207e0ed6b70c778430da2398609b60411b6b644752159691c154";


const toWei = n => ethers.BigNumber.from(10).pow(18).mul(n)
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

const GAS_REPORT = {}

async function gasToCost(tx){
    let response = await tx.wait();
    let gasPrice = 0.000000005;
    let bnbPrice = 650;
    return [response.gasUsed, (gasPrice * response.gasUsed * bnbPrice).toFixed(2)];
}

let accounts, owner, user, squidBusNFT, squidPlayerNFT,  launch, BSW;

//squidBusNFT initialize parameters
const baseURIBusNFT = ``
const maxBusLevel = 5
const minBusBalance = 2
const maxBusBalance = 5
const busAdditionPeriod = 7 * 86400
//squidPlayerNFT initialize parameters
const baseURIPlayerNFT = ``
//Launchpad constructor parameters
//     ISquidPlayerNFT _squidPlayerNFT,
//     ISquidBusNFT _squidBusNFT,
//     IERC20 _dealToken,
//     address _treasuryAddress



before(async function () {
    accounts = await ethers.getSigners();
    owner = accounts[0];
    user = accounts[1];

    const Token = await ethers.getContractFactory('Token')
    BSW  = await Token.deploy('BSW',  'BSW',  toWei(1e6))

    const SquidBusNFT = await ethers.getContractFactory('SquidBusNFT')
    squidBusNFT = await upgrades.deployProxy(SquidBusNFT, [baseURIBusNFT, maxBusLevel, minBusBalance, maxBusBalance, busAdditionPeriod])

    const SquidPlayerNFT = await ethers.getContractFactory('SquidPlayerNFT')
    squidPlayerNFT = await upgrades.deployProxy(SquidPlayerNFT, [baseURIPlayerNFT])

    const Launch = await ethers.getContractFactory(`LaunchpadNftMysteryBoxes`);
    launch = await Launch.deploy(squidPlayerNFT.address, squidBusNFT.address, BSW.address, owner.address);
    const TOKEN_MINTER_ROLE  = await squidBusNFT.TOKEN_MINTER_ROLE()
    await squidBusNFT.grantRole(TOKEN_MINTER_ROLE, launch.address);
    await squidPlayerNFT.grantRole(TOKEN_MINTER_ROLE, launch.address);
})

describe(`Check launch contract`, async function (){
    it(`Should buy NFT token by launchpad`, async function (){
        await BSW.transfer(user.address, toWei(1e6))
        await BSW.connect(user).approve(launch.address, toWei(1e6))

        let winNumbers = new Map();
        winNumbers.constructor.prototype.increment = function (key) {
            this.has(key) ? this.set(key, this.get(key) + 1) : this.set(key, 1)
        }

        const maxToUser = 5000//+ await launch.maxToUser()
        let event

        for(let i = 0; i < maxToUser; i++){
            const BOX_PRICE = await launch.boxPrice()
            const BSW_BEFORE_PLAYER = await BSW.balanceOf(user.address)
            const BSW_BEFORE_OWNER = await BSW.balanceOf(owner.address)

            const PLAYERNFT_BEFORE = await squidPlayerNFT.balanceOf(user.address)
            const BUSNFT_BEFORE = await squidBusNFT.balanceOf(user.address)



            tx = await launch.connect(user).buyBOX()
            res = await tx.wait()
            event = res.events?.filter((x) => {return x.event === "LaunchpadExecuted"})
            const boxId = event[0].args.boxIndex.toNumber()
            winNumbers.increment(boxId)
            GAS_REPORT[`buyBOX[${boxId}]`] = extractCost(await tx.wait())
            process.stdout.write(`${i}/${maxToUser}\r`)

            // const box = await launch.getBoxInfo(boxId)
            const PLAYERNFT_AFTER = await squidPlayerNFT.balanceOf(user.address)
            const BUSNFT_AFTER = await squidBusNFT.balanceOf(user.address)

            // expect(PLAYERNFT_BEFORE.add(box[0].length)).eq(PLAYERNFT_AFTER)
            // expect(BUSNFT_BEFORE.add(box[1].length)).eq(BUSNFT_AFTER)



            const BSW_AFTER_PLAYER = await BSW.balanceOf(user.address)
            const BSW_AFTER_OWNER = await BSW.balanceOf(owner.address)

            // expect(BSW_BEFORE_PLAYER.sub(BOX_PRICE)).eq(BSW_AFTER_PLAYER)
            // expect(BSW_BEFORE_OWNER.add(BOX_PRICE)).eq(BSW_AFTER_OWNER)
        }

        console.log(`Runs ${maxToUser}`)

        const probabilyBase = +await launch.probabilityBase()
        const table = {}

        for (let i = 0 ; i < 10; i++){
            const probability = +await launch.probability(i)

            table[i] = {
                actual: Math.trunc(winNumbers.get(i) / maxToUser * 100) / 100,
                expect: Math.trunc(probability/ probabilyBase * 100) / 100
            }
        }

        console.table(table)
    })

    it('GAS REPORT PRINT', async () => {
        console.table(GAS_REPORT)
    })
})
