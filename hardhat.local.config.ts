import { HardhatUserConfig } from "hardhat/config";
import 'dotenv/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-solhint';
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      gas: 10000000,
      mining: {
        auto: true,
        interval: 5000,
      },
    },
    localhost: {
      allowUnlimitedContractSize: true,
      gas: 10000000,
      mining: {
        auto: true,
        interval: 5000,
      },
      asyncKnifeHitAddress: process.env.TESTNET_ASYNC_KNIFE_HIT_ADDRESS
    },
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
    timeout: 20000000,
    color: true,
  },
};

export default config;
