//npx hardhat flatten ./contracts/NFTMinter.sol > ./temp/flatten/NFTMinterFlatten.sol
// npx hardhat flatten ./contracts/SquidBusNFT.sol > ./temp/flatten/SquidBusNFTFlatten.sol
// npx hardhat flatten ./contracts/MainSquidGame.sol > ./temp/flatten/MainSquidGameFlatten.sol
// npx hardhat flatten ./contracts/SquidPlayerNFT.sol > ./temp/flatten/SquidPlayerNFTFlatten.sol

const hre = require('hardhat');
const { ethers } = require(`hardhat`);
const deployedContracts = require('../deployGameAddresses.json')
const deployedContractsNFT = require('../deployNFTAddresses.json')

const contractAddresses = [
    // deployedContractsNFT.proxy_squidPlayerNFT
    deployedContracts.proxy_mainSquidGame,
    // deployedContracts.proxy_nftMinter
]

async function getImplementationAddress(proxyAddress) {
    const implHex = await ethers.provider.getStorageAt(
        proxyAddress,
        "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    );
    return ethers.utils.hexStripZeros(implHex);
}

async function main() {
    console.log(`Get implementation addresses`);
    let implAddresses = [];
    for(let i in contractAddresses){
        implAddresses.push(await getImplementationAddress(contractAddresses[i]));
    }
    console.log(implAddresses);

    for(let i in implAddresses){
        console.log(`Verify ${implAddresses[i]} contract`);
        let res = await hre.run("verify:verify", {
            address: implAddresses[i],
            constructorArguments: [],
            optimizationFlag: true
        })
        console.log(res);
    }

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });