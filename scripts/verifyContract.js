//npx hardhat flatten ./contracts/NFTMinter.sol > ./temp/flatten/NFTMinterFlatten.sol
// npx hardhat flatten ./contracts/SquidBusNFT.sol > ./temp/flatten/SquidBusNFTFlatten.sol
// npx hardhat flatten ./contracts/MainSquidGame.sol > ./temp/flatten/MainSquidGameFlatten.sol
// npx hardhat flatten ./contracts/SquidPlayerNFT.sol > ./temp/flatten/SquidPlayerNFTFlatten.sol

const hre = require('hardhat');
const { ethers } = require(`hardhat`);
const deployedContracts = require('deploymentCache.json')

// squidBusNFT deployed to 0xD0CA2DD2477BA074E05fC7A4a4d026262c20E90f
// squidPlayerNFT deployed to 0x0E350AA4a89DD83e8bDdd910b76682E384Db3809
// game deployed to 0x9d810D8B543D7FAE41c4bbb902DCA4EDfE3729D6
// nftMinter deployed to 0x692665bBECfDb4850458809b4D47bEec82687415

// squidBusNFT implementation address:  0x1e345934e10b8062d71c67e6f310f8b49504bf93
// squidPlayerNFT implementation address:  0x834e1e88253e04d8e20c5674022f4afae08ed13e
// game implementation address:  0x9199ba916f6c36eaf64d33ba90c262268069e6bd
// nftMinter implementation address:  0x80d1379fd908bf33c5b0bb0222336c1833249650


// const contractAddresses = [
//     `0x634987bFEAf2A92c02d7c2B91eA8ef51a15051a4`,
//     `0xC18B1b867B2A8bF1c9a15bF65552A62Ea377fDc2`,
//     `0x32ED4Fe0D058cDF014F76E701262A04746f20aef`,
//     `0x11bb5cB3A737D1A51D888e50e6874e82096d1Da7`
// ]

const contractAddresses = [
    deployedContracts.proxy_squidBusNFT,
    deployedContracts.proxy_squidPlayerNFT ,
    deployedContracts.proxy_mainSquidGame,
    deployedContracts.proxy_nftMinter
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