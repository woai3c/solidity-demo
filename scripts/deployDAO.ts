import { ethers, run, upgrades } from 'hardhat'
import { writeFileSync } from 'fs'
import { delay } from './utils'
import type { IGovernance, IVault } from './types'

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
  // ProxyAdmin 的时间锁定期，可选
  adminDelay?: number
}

async function deployDAOContracts(config: DeployConfig) {
  const [deployer] = await ethers.getSigners()
  console.log('Deploying DAO contracts with account:', deployer.address)

  // 0. 部署 ProxyAdmin (在所有可升级合约之前部署)
  console.log('Deploying ProxyAdmin...')
  const ProxyAdmin = await ethers.getContractFactory('ProxyAdmin')
  const proxyAdmin = await ProxyAdmin.deploy()
  await proxyAdmin.waitForDeployment()
  const proxyAdminAddress = await proxyAdmin.getAddress()
  console.log('ProxyAdmin deployed to:', proxyAdminAddress)

  // 1. 部署 AccessControl
  console.log('Deploying AccessControl...')
  const AccessControl = await ethers.getContractFactory('AccessControl')
  const accessControl = await AccessControl.deploy(config.merkleRoot)
  await accessControl.waitForDeployment()
  const accessControlAddress = await accessControl.getAddress()
  console.log('AccessControl deployed to:', accessControlAddress)

  // 2. 部署 MultiSig
  console.log('Deploying MultiSig...')
  const MultiSig = await ethers.getContractFactory('MultiSig')
  const multiSig = await MultiSig.deploy(config.signers, config.threshold, config.delay)
  await multiSig.waitForDeployment()
  const multiSigAddress = await multiSig.getAddress()
  console.log('MultiSig deployed to:', multiSigAddress)

  // 3. 部署 Vault (可升级)
  console.log('Deploying Vault...')
  const Vault = await ethers.getContractFactory('Vault')
  const vault = (await upgrades.deployProxy(Vault, [
    config.name,
    config.symbol,
    config.supportedTokens,
    accessControlAddress,
  ])) as unknown as IVault

  await vault.waitForDeployment()
  const vaultAddress = await vault.getAddress()
  console.log('Vault proxy deployed to:', vaultAddress)

  // 4. 部署 Strategy (可升级)
  console.log('Deploying Strategy...')
  const Strategy = await ethers.getContractFactory('Strategy')
  const strategy = await upgrades.deployProxy(Strategy, [vaultAddress, config.router])
  await strategy.waitForDeployment()
  const strategyAddress = await strategy.getAddress()

  // 5. 部署 Governance (可升级)
  console.log('Deploying Governance...')
  const Governance = await ethers.getContractFactory('Governance')
  const governance = (await upgrades.deployProxy(Governance, [
    vaultAddress,
    config.votingDelay,
    config.votingPeriod,
    config.quorumVotes,
  ])) as unknown as IGovernance

  await governance.waitForDeployment()
  const governanceAddress = await governance.getAddress()

  // 6. 设置合约间的权限关系
  console.log('Setting up contract relationships...')

  // 设置 Vault 的关联合约
  await vault.setGovernance(governanceAddress)
  await vault.setStrategy(strategyAddress)
  await vault.setAccessControl(accessControlAddress)

  // Transfer ownership to MultiSig
  console.log('Transferring ownership to MultiSig...')
  await vault.transferOwnership(multiSigAddress)
  await strategy.transferOwnership(multiSigAddress)
  await governance.transferOwnership(multiSigAddress)

  // 7. 写入部署信息
  const deployInfo = {
    ProxyAdmin: proxyAdminAddress,
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

  // 8. 验证合约
  await verifyContracts({
    ProxyAdmin: {
      address: proxyAdminAddress,
      args: [],
    },
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
      args: [], // 代理合约不需要构造参数
    },
    Strategy: {
      address: strategyAddress,
      args: [],
    },
    Governance: {
      address: governanceAddress,
      args: [],
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
  for (const [name, { address, args }] of Object.entries(contracts)) {
    try {
      await run('verify:verify', {
        address,
        constructorArguments: args,
      })
      console.log(`${name} verified successfully`)
    } catch (error) {
      console.error(`Error verifying ${name}:`, error)
      // 如果验证失败，稍后重试
      setTimeout(() => {
        run('verify:verify', {
          address,
          constructorArguments: args,
        })
      }, delay)
    }
  }
}

async function main() {
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
    merkleRoot: '0x0000000000000000000000000000000000000000000000000000000000000000', // 测试用空merkle root
    signers: [
      process.env.SINER_WALLET1!, // 替换为你的测试钱包地址
      process.env.SINER_WALLET2!, // 测试用地址
      process.env.SINER_WALLET3!, // 测试用地址
    ],
    threshold: 2, // 测试环境只需要1个签名
    delay: 86400, // 添加延迟时间配置(1天)
    adminDelay: 1800, // 约6小时
  }

  const deployInfo = await deployDAOContracts(config)
  console.log('DAO deployed successfully!', deployInfo)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
