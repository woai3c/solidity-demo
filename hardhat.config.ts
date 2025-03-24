import type { HardhatUserConfig } from 'hardhat/types'
import 'dotenv/config'
import '@nomicfoundation/hardhat-toolbox'
import 'solidity-coverage'
import 'tsconfig-paths/register'
import '@nomicfoundation/hardhat-ethers'
import 'hardhat-gas-reporter'
import 'hardhat-contract-sizer'
import '@nomicfoundation/hardhat-foundry'

const config = {
  solidity: {
    version: '0.8.20',
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.TESTNET_INFURA_PROJECT_ID}`,
      accounts: [`0x${process.env.TESTNET_PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  paths: {
    tests: './tests',
    sources: './contracts',
  },
  foundry: {
    testDir: './tests',
    spinUpNode: true,
  },
  gasReporter: {
    enabled: !!process.env.REPORT_GAS,
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    outputFile: 'gas-report.txt',
    noColors: true,
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },
  mocha: {
    timeout: 40000,
  },
}

export default config
