//npx hardhat flatten ./contracts/NFTMinter.sol > ./temp/flatten/NFTMinterFlatten.sol
// npx hardhat flatten ./contracts/SquidBusNFT.sol > ./temp/flatten/SquidBusNFTFlatten.sol
// npx hardhat flatten ./contracts/MainSquidGameV2.sol > ./temp/flatten/MainSquidGameFlatten.sol
// npx hardhat flatten ./contracts/SquidPlayerNFT.sol > ./temp/flatten/SquidPlayerNFTFlatten.sol

const hre = require('hardhat');
const { ethers } = require(`hardhat`);
// const deployedContracts = require('../deployGameAddresses.json')
// const deployedContractsNFT = require('../deployNFTAddresses.json')

const contractAddresses = [
    // '0x6d57712416eD4890e114A37E2D84AB8f9CEe4752',
    // '0xb00ED7E3671Af2675c551a1C26Ffdcc5b425359b',
    '0xCCc78DF56470b70cb901FCc324A8fBbE8Ab5304B',
    // '0xF28743d962AD110d1f4C4266e5E48E94FbD85285'
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
