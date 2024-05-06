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
            mining: {
              auto: true,
              interval: 5000,
            },
            treasuryAddress: process.env.TESTNET_TREASURY_ADDRESS,
            mainAddress: process.env.TESTNET_DUCK_RACE_ADDRESS,
            contractFactory: process.env.CONTRACT_FACTORY_NAME
          } as any,
          localhost: {
            allowUnlimitedContractSize: true,
            gas: 100000000,
            mining: {
              auto: true,
              interval: 5000,
            },
            treasuryAddress: process.env.TESTNET_TREASURY_ADDRESS,
            mainAddress: process.env.TESTNET_DUCK_RACE_ADDRESS,
            contractFactory: process.env.CONTRACT_FACTORY_NAME
          } as any,
          arcadeDev: {
            url: 'https://testnet.bitcoinarcade.xyz/rpc',
            accounts: [process.env.TESTNET_DEPLOYER_PRIVATE_KEY],
            chainId: 23508,
            allowUnlimitedContractSize: true,
            treasuryAddress: process.env.ARCADE_TREASURY_ADDRESS,
            mainAddress: process.env.ARCADE_DEV_DUCK_RACE_ADDRESS,
            contractFactory: process.env.CONTRACT_FACTORY_NAME
          } as any,
          testnet: {
            url: 'https://l2-node.regtest.trustless.computer/',
            accounts: [process.env.TESTNET_DEPLOYER_PRIVATE_KEY],
            chainId: 42070,
            allowUnlimitedContractSize: true,
            treasuryAddress: process.env.TESTNET_TREASURY_ADDRESS,
            mainAddress: process.env.TESTNET_DUCK_RACE_ADDRESS,
            contractFactory: process.env.CONTRACT_FACTORY_NAME
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
                chainId: 90452,
                urls: {
                    apiURL: 'https://testnet.bitcoinarcade.xyz/api',
                    browserURL: 'https://testnet.bitcoinarcade.xyz/',
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
