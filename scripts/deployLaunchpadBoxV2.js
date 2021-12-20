const { ethers, network, upgrades } = require(`hardhat`);
const hre = require("hardhat");
const deployedContracts = require('../deployNFTAddresses.json')

const LaunchpadNftMysteryBoxesAddress = ``

// LaunchpadNftMysteryBoxes deployed to 0x68e258007727AF31EFB3E68500CFB82f425DBae8


const TOKEN_MINTER_ROLE = `0x262c70cb68844873654dc54487b634cb00850c1e13c785cd0d96a2b89b829472`;

//launchpad parameters
const squidPlayerNFTAddress = deployedContracts.proxy_squidPlayerNFT
const squidBusNFTAddress = deployedContracts.proxy_squidBusNFT
const dealTokenAddress = `0x965f527d9159dce6288a2219db51fc6eef120dd1`
const masterChefAddress = `0xDbc1A13490deeF9c3C12b44FE77b503c1B061739`
const autoBSWAddress = `0x97A16ff6Fd63A46bf973671762a39f3780Cda73D`
const biswapNFTAddress = `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`

const treasuryAddress =  `0x5a63517AF37686B8D1d7DC3F09b226936e419B4E`

let startBlock = 13643170;
let launchpad, squidBusNFT, squidPlayerNFT

async function main() {
    const [deployer] = await ethers.getSigners();
    const SquidBusNFT = await ethers.getContractFactory(`SquidBusNFT`);
    const SquidPlayerNFT = await ethers.getContractFactory(`SquidPlayerNFT`);
    squidBusNFT = await SquidBusNFT.attach(squidBusNFTAddress);
    squidPlayerNFT = await SquidPlayerNFT.attach(squidPlayerNFTAddress);

    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    console.log(`Start deploying LaunchpadNftMysteryBox V2 contract`);
    const Launchpad = await ethers.getContractFactory(`LaunchpadMysteryBoxV2`);

    launchpad = await Launchpad.deploy(squidPlayerNFTAddress, squidBusNFTAddress, dealTokenAddress, masterChefAddress, autoBSWAddress, biswapNFTAddress, startBlock, treasuryAddress, {nonce: ++nonce, gasLimit: 5e6});
    await launchpad.deployed();
    console.log(`LaunchpadNftMysteryBoxes deployed to ${launchpad.address}`);

    console.log(`Setup roles`)
    await squidBusNFT.grantRole(TOKEN_MINTER_ROLE, launchpad.address, {nonce: ++nonce, gasLimit: 3e6});
    await squidPlayerNFT.grantRole(TOKEN_MINTER_ROLE, launchpad.address, {nonce: ++nonce, gasLimit: 3e6});

    // //verify contract
    // console.log(`Verify ${LaunchpadNftMysteryBoxesAddress} contract`);
    // let res = await hre.run("verify:verify", {
    //     address: LaunchpadNftMysteryBoxesAddress,
    //     constructorArguments: [squidPlayerNFTAddress, squidBusNFTAddress, dealTokenAddress, treasuryAddress],
    //     optimizationFlag: true
    // })
    // console.log(res);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
