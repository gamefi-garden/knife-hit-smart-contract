import { HardhatUserConfig } from 'hardhat/config';
import 'dotenv/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-solhint';
import '@openzeppelin/hardhat-upgrades';
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-upgradable";

// import './tasks/queryEvents';
// import './tasks/queryEvents0';
// import './tasks/queryEvents8';

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
            knifeHitAddress: process.env.TESTNET_DUCK_RACE_ADDRESS,
            contractFactory: process.env.CONTRACT_FACTORY_NAME
          } as any,
          localhost: {
            allowUnlimitedContractSize: true,
            gas: 100000000,
            mining: {
              auto: true,
              interval: 5000,
            },
            ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
            zksync: true, // Flag that targets zkSync Era.
            deployerKey: process.env.TESTNET_DEPLOYER_PRIVATE_KEY,

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
            knifeHitAddress: process.env.ARCADE_DEV_DUCK_RACE_ADDRESS,
            contractFactory: process.env.CONTRACT_FACTORY_NAME
          } as any,
          testnet: {
            url: 'https://l2-node.regtest.trustless.computer/',
            accounts: [process.env.TESTNET_DEPLOYER_PRIVATE_KEY],
            chainId: 42070,
            allowUnlimitedContractSize: true,
            deployerKey: process.env.TESTNET_DEPLOYER_PRIVATE_KEY,
            treasuryAddress: process.env.TESTNET_TREASURY_ADDRESS,
            knifeHitAddress: process.env.TESTNET_DUCK_RACE_ADDRESS,
            contractFactory: process.env.CONTRACT_FACTORY_NAME
          } as any
          ,
          zkTestnet: {
            url: 'https://rpc.zkbvml2-testnet.trustless.computer',
            accounts: [process.env.TESTNET_DEPLOYER_PRIVATE_KEY],
            chainId: 22102,
            allowUnlimitedContractSize: true,
            ethNetwork: "https://testnet.runechain.com/rpc", // The Ethereum Web3 RPC URL.
            zksync: true, // Flag that targets zkSync Era.
            deployerKey: process.env.TESTNET_DEPLOYER_PRIVATE_KEY,

            treasuryAddress: process.env.TESTNET_TREASURY_ADDRESS,
            mainAddress: process.env.TESTNET_DUCK_RACE_ADDRESS,
            contractFactory: process.env.CONTRACT_FACTORY_NAME
            
        } as any
    },
    // etherscan: {
    //     apiKey: {
    //         tc: '123'
    //     },
    //     customChains: [
    //         {
    //             network: 'testnet',
    //             chainId: 42069,
    //             urls: {
    //                 apiURL: 'https://explorer.nos-testnet.trustless.computer/api',
    //                 browserURL: 'https://explorer.nos-testnet.trustless.computer/',
    //             },
    //         },
    //         {
    //             network: 'tc',
    //             chainId: 42213,
    //             urls: {
    //                 apiURL: 'https://explorer.l2.trustless.computer/api',
    //                 browserURL: 'https://explorer.l2.trustless.computer/',
    //             },
    //         },
    //     ],
    // },
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
        timeout: 20000,
        color: true,
        reporter: 'mocha-multi-reporters',
        reporterOptions: {
            configFile: './mocha-report.json',
        },
    },
};

export default config;
