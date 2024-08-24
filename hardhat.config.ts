import type { HardhatUserConfig } from 'hardhat/types'
import 'dotenv/config'
import '@nomicfoundation/hardhat-toolbox'
import 'solidity-coverage'
import 'tsconfig-paths/register'

const config: HardhatUserConfig = {
  solidity: '0.8.20',
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.TESTNET_INFURA_PROJECT_ID}`,
      accounts: [`0x${process.env.TESTNET_PRIVATE_KEY}`],
    },
    // mainnet: {
    //   url: `https://sepolia.infura.io/v3/${process.env.MAINNET_INFURA_PROJECT_ID}`,
    //   accounts: [`0x${process.env.MAINNET_PRIVATE_KEY}`],
    // },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  paths: {
    tests: './tests',
  },
}

export default config
