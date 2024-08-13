import type { ethers as hardhatEthers, HardhatRuntimeEnvironment } from 'hardhat'

declare global {
  const ethers: typeof hardhatEthers
  const hre: HardhatRuntimeEnvironment
}

export {}
