import { HardhatUserConfig } from 'hardhat/config';
import 'dotenv/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-solhint';
import '@openzeppelin/hardhat-upgrades';
import 'hardhat-contract-sizer'

const config: HardhatUserConfig = {
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {
            // forking: { url: "https://node.l2.trustless.computer/" },
            allowUnlimitedContractSize: true,
            gas: 100000000,
            blockGasLimit: 1000000000,
        } as any,
        testnet: {
            url: 'https://l2-node.regtest.trustless.computer/',
            accounts: [process.env.TESTNET_DEPLOYER_PRIVATE_KEY],
            chainId: 42070,
            allowUnlimitedContractSize: true,
            treasuryAddress: process.env.TESTNET_TREASURY_ADDRESS,
            gameLibraryAddress: process.env.TESTNET_GAME_LIBRARY_ADDRESS,
            asyncGameHubAddress: process.env.TESTNET_ASYNC_GAME_HUB_ADDRESS,
        } as any,
        mainnet: {
            url: "https://node.l2.trustless.computer/",
            accounts: [process.env.MAINNET_DEPLOYER_PRIVATE_KEY],
            chainId: 42213,
            allowUnlimitedContractSize: true,
            treasuryAddress: process.env.MAINNET_TREASURY_ADDRESS,
            gameLibraryAddress: process.env.MAINNET_GAME_LIBRARY_ADDRESS,
            asyncGameHubAddress: process.env.MAINNET_ASYNC_GAME_HUB_ADDRESS,
        } as any,
    },
    etherscan: {
        apiKey: {
            testnet: '123',
            mainnet: '123'
        },
        customChains: [
            {
                network: 'testnet',
                chainId: 42070,
                urls: {
                    apiURL: 'https://explorer.regtest.trustless.computer/api',
                    browserURL: 'https://explorer.regtest.trustless.computer/',
                },
            },
            {
                network: 'mainnet',
                chainId: 42213,
                urls: {
                    apiURL: 'https://explorer.l2.trustless.computer/api',
                    browserURL: 'https://explorer.l2.trustless.computer/',
                },
            },
        ],
    },
    solidity: {
        compilers: [
            {
                version: '0.8.19',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                    viaIR: true,
                    // outputSelection: {
                    //     "*": {
                    //         "*": ["storageLayout"],
                    //     },
                    // },
                },
            },
        ],
    },
    paths: {
        sources: './contracts',
        tests: './tests',
        cache: './cache',
        artifacts: './artifacts',
    },
    mocha: {
        timeout: 2000000,
        color: true,
        reporter: 'mocha-multi-reporters',
        reporterOptions: {
            configFile: './mocha-report.json',
        },
    },
};

export default config;
