const { expect } = require(`chai`);
const { ethers, upgrades, network } = require(`hardhat`);
const {BigNumber} = require("ethers");


function expandTo18Decimals(n) {
    return (new BigNumber.from(n)).mul((new BigNumber.from(10)).pow(18))
}

async function numberLastBlock(){
    return (await ethers.provider.getBlock(`latest`)).number;
}

async function gasToCost(tx){
    let response = await tx.wait();
    let gasPrice = 0.000000005;
    let bnbPrice = 570;
    return [response.gasUsed, (gasPrice * response.gasUsed * bnbPrice).toFixed(2)];
}

let game, accounts, owner, tokenUSD, tokenBSW;

before(async function (){
    accounts = await ethers.getSigners();
    owner = accounts[0];
    tokenUSD = `0x55d398326f99059fF775485246999027B3197955`;
    tokenBSW = `0x965f527d9159dce6288a2219db51fc6eef120dd1`;
    let Game = await ethers.getContractFactory('SquidTrialGame');
    game = await upgrades.deployProxy(Game,[owner.address, tokenUSD, tokenBSW]);
    await game.deployed();

    // const BiswapNft = await ethers.getContractFactory("BiswapNFT");
    // biswapNft = await upgrades.deployProxy(BiswapNft, ["https://", expandTo18Decimals(1), 14]);
    // await biswapNft.deployed();
})

describe(`Check random days and roi`, async function(){

    it(`Should generate random day and roi`, async function(){
        for(let i = 0; i < 500; i++){
            let res = await game._randomGameParameters();
            console.log(res.toString());
            await network.provider.send("evm_mine");
        }
    })
})