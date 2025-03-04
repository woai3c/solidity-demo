import { ethers, run } from 'hardhat'
import { writeFileSync } from 'fs'
import { delay } from './utils/utils'
import { generateMerkleRoot } from './utils/generateMerkleRoot'

export interface DeployConfig {
  // 基础配置
  name: string
  symbol: string
  supportedTokens: string[]
  // 治理配置
  votingDelay: number
  votingPeriod: number
  quorumVotes: string | number
  // DeFi 配置
  router: string
  // 访问控制配置
  merkleRoot: string
  // 多签配置
  signers: string[]
  threshold: number
  delay: number
}

async function deployDAOContracts(config: DeployConfig) {
  const [deployer] = await ethers.getSigners()
  console.log('Deploying DAO contracts with account:', deployer.address)

  // 1. 部署 AccessControl
  console.log('Deploying AccessControl...')
  const AccessControlFactory = await ethers.getContractFactory('CustomAccessControl')
  const accessControl = await AccessControlFactory.deploy(config.merkleRoot)
  await accessControl.waitForDeployment()
  const accessControlAddress = await accessControl.getAddress()
  console.log('AccessControl deployed to:', accessControlAddress)

  // 2. 部署 MultiSig
  console.log('Deploying MultiSig...')
  const MultiSigFactory = await ethers.getContractFactory('MultiSig')
  const multiSig = await MultiSigFactory.deploy(config.signers, config.threshold, config.delay)
  await multiSig.waitForDeployment()
  const multiSigAddress = await multiSig.getAddress()
  console.log('MultiSig deployed to:', multiSigAddress)

  // 3. 部署 Vault (普通合约)
  console.log('Deploying Vault...')
  const VaultFactory = await ethers.getContractFactory('Vault')
  const vault = await VaultFactory.deploy(config.name, config.symbol, config.supportedTokens, accessControlAddress)
  await vault.waitForDeployment()
  const vaultAddress = await vault.getAddress()
  console.log('Vault deployed to:', vaultAddress)

  // 4. 部署 Strategy (普通合约)
  console.log('Deploying Strategy...')
  const StrategyFactory = await ethers.getContractFactory('Strategy')
  const strategy = await StrategyFactory.deploy(
    vaultAddress,
    config.router,
    multiSigAddress, // 初始设置为 multiSig
  )
  await strategy.waitForDeployment()
  const strategyAddress = await strategy.getAddress()
  console.log('Strategy deployed to:', strategyAddress)

  // 5. 部署 Governance (普通合约)
  console.log('Deploying Governance...')
  const GovernanceFactory = await ethers.getContractFactory('Governance')
  const governance = await GovernanceFactory.deploy(
    vaultAddress, // 作为治理代币
    strategyAddress,
    config.votingDelay,
    config.votingPeriod,
    config.quorumVotes,
  )
  await governance.waitForDeployment()
  const governanceAddress = await governance.getAddress()
  console.log('Governance deployed to:', governanceAddress)

  // 设置合约间的关系
  console.log('Setting up contract relationships...')

  // 更新 Strategy 的 governance
  await strategy.setGovernance(governanceAddress)

  // 设置 Vault 的关联合约
  await vault.setGovernance(governanceAddress)
  await vault.setStrategy(strategyAddress)
  await vault.setAccessControl(accessControlAddress)

  // 转移所有权给 MultiSig
  console.log('Transferring ownership to MultiSig...')
  await vault.transferOwnership(multiSigAddress)
  await strategy.transferOwnership(multiSigAddress)
  await governance.transferOwnership(multiSigAddress)

  // 写入部署信息
  const deployInfo = {
    AccessControl: accessControlAddress,
    MultiSig: multiSigAddress,
    Vault: vaultAddress,
    Strategy: strategyAddress,
    Governance: governanceAddress,
    network: (await ethers.provider.getNetwork()).name,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
  }

  writeContractAddresses(deployInfo)
  console.log('Contract addresses saved to cache')

  // 验证合约
  await verifyContracts({
    AccessControl: {
      address: accessControlAddress,
      args: [config.merkleRoot],
    },
    MultiSig: {
      address: multiSigAddress,
      args: [config.signers, config.threshold, config.delay],
    },
    Vault: {
      address: vaultAddress,
      args: [config.name, config.symbol, config.supportedTokens, accessControlAddress],
    },
    Strategy: {
      address: strategyAddress,
      args: [vaultAddress, config.router, multiSigAddress],
    },
    Governance: {
      address: governanceAddress,
      args: [vaultAddress, strategyAddress, config.votingDelay, config.votingPeriod, config.quorumVotes],
    },
  })

  return deployInfo
}

function writeContractAddresses(addresses: Record<string, string>) {
  for (const [name, address] of Object.entries(addresses)) {
    writeFileSync(`cache/${name}`, address)
  }
}

async function verifyContracts(contracts: Record<string, { address: string; args: any[] }>) {
  console.log('Starting contract verification...')

  for (const [name, { address, args }] of Object.entries(contracts)) {
    try {
      console.log(`Verifying ${name} at ${address}...`)
      await run('verify:verify', {
        address,
        constructorArguments: args,
      })
      console.log(`${name} verified successfully`)
    } catch (error) {
      console.error(`Error verifying ${name}:`, error)
      // 如果验证失败，稍后重试
      console.log(`Will retry verifying ${name} after 10 seconds delay...`)
      await delay(10000)

      try {
        await run('verify:verify', {
          address,
          constructorArguments: args,
        })
        console.log(`${name} verified successfully on retry`)
      } catch (retryError) {
        console.error(`Failed to verify ${name} on retry:`, retryError)
      }
    }
  }
}

async function main() {
  const signers = [
    process.env.SINER_WALLET1!, // 替换为你的测试钱包地址
    process.env.SINER_WALLET2!, // 测试用地址
    process.env.SINER_WALLET3!, // 测试用地址
  ]

  const config: DeployConfig = {
    name: 'Test DAO',
    symbol: 'TDAO',
    supportedTokens: [
      '0x779877A7B0D9E8603169DdbD7836e478b4624789', // LINK (Sepolia)
      '0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9', // WETH (Sepolia)
      '0x8267cF9254734C6Eb452a7bb9AAF97B392258b21', // DAI (Sepolia)
    ],
    votingDelay: 20, // 约1小时 (Sepolia出块时间约12秒)
    votingPeriod: 100, // 约5小时
    quorumVotes: String(ethers.parseEther('100')), // 100 tokens
    router: '0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008', // Sepolia Uniswap V2 Router
    merkleRoot: generateMerkleRoot(signers).root, // 测试用空merkle root
    signers,
    threshold: 2, // 测试环境只需要1个签名
    delay: 86400, // 添加延迟时间配置(1天)
  }
  console.log(config.merkleRoot)
  const deployInfo = await deployDAOContracts(config)
  console.log('DAO deployed successfully!', deployInfo)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
