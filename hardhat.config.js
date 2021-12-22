require("@nomiclabs/hardhat-waffle");
require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
const { mnemonic, bscScanApiKey, privatKey } = require('./secrets.json');

task("accounts", "Prints the list of accounts", async () => {
	const accounts = await ethers.getSigners();

	for (const account of accounts) {
		console.log(account.address);
	}
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
	defaultNetwork: "hardhat",
	networks: {
		localhost: {
			url: "http://127.0.0.1:8545"
		},
		hardhat: {
			blockGasLimit: 99999999
		},
		testnetBSC: {
			url: "https://data-seed-prebsc-1-s1.binance.org:8545",
			chainId: 97,
			gasPrice: 20e9,
			accounts: { mnemonic: mnemonic }
		},
		mainnetBSC: {
			url: "https://speedy-nodes-nyc.moralis.io/3ad31c74f70f3d5894c50440/bsc/mainnet",// "http://68.183.66.58:8545" //"https://bsc-dataseed.binance.org/", //"https://speedy-nodes-nyc.moralis.io/3ad31c74f70f3d5894c50440/bsc/mainnet",
			chainId: 56,
			gasPrice: 20e9,
			accounts: [privatKey]
		},
		testnetMatic: {
			url: "https://rpc-mumbai.maticvigil.com/",
			chainId: 80001,
			gasPrice: 20000000000,
			accounts: { mnemonic: mnemonic }
		},
	},
	etherscan: {
		apiKey: bscScanApiKey
	},
	solidity: {
		compilers: [
			{
				version: "0.8.9",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200,
					}
				}
			},
			{
				version: "0.8.2",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200,
					}
				}
			}
		],
		outputSelection: {
			"*": {
				"*": ["storageLayout"]
			}
		}
	},
	paths: {
		sources: "./contracts",
		tests: "./test",
		cache: "./cache",
		artifacts: "./artifacts"
	},
	mocha: {
		timeout: 200000
	}
};