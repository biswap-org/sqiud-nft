const { ethers, network, upgrades } = require(`hardhat`);
const hre = require("hardhat");

const LaunchpadNftMysteryBoxesAddress = ``

const TOKEN_MINTER_ROLE = `0x262c70cb68844873654dc54487b634cb00850c1e13c785cd0d96a2b89b829472`;

//launchpad parameters
const squidPlayerNFTAddress = ``
const squidBusNFTAddress = ``
const dealTokenAddress = ``
const treasuryAddress =  ``

let launchpad, squidBusNFT, squidPlayerNFT

async function main() {
    const [deployer] = await ethers.getSigners();
    const SquidBusNFT = await ethers.getContractFactory(`SquidBusNFT`);
    const SquidPlayerNFT = await ethers.getContractFactory(`SquidPlayerNFT`);
    squidBusNFT = await SquidBusNFT.attach(squidBusNFTAddress);
    squidPlayerNFT = await SquidPlayerNFT.attach(squidPlayerNFTAddress);

    console.log(`Deployer address: ${ deployer.address}`);
    let nonce = await network.provider.send(`eth_getTransactionCount`, [deployer.address, "latest"]) - 1;

    console.log(`Start deploying LaunchpadNftMysteryBoxes contract`);
    const Launchpad = await ethers.getContractFactory(`LaunchpadNftMysteryBoxes`);
    launchpad = await Launchpad.deploy(squidPlayerNFTAddress, squidBusNFTAddress, dealTokenAddress, treasuryAddress, {nonce: ++nonce, gasLimit: 3e6});
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
