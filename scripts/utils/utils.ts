import type { BaseContract, ContractFactory } from 'ethers'
import { writeFileSync } from 'fs'
import { run } from 'hardhat'

export const delay = 30000

async function verifyContract(deployedAddress: string, constructorArguments: (string | number)[]) {
  try {
    await run('verify:verify', {
      address: deployedAddress,
      constructorArguments,
    })

    console.log('Contract verified successfully')
  } catch (error) {
    console.error('Error verifying the contract:', error)
    setTimeout(() => verifyContract(deployedAddress, constructorArguments), delay)
  }
}

export async function deployContract(
  contractName: string,
  callback: (contract: ContractFactory, ...args: string[]) => Promise<[BaseContract, (string | number)[]]>,
) {
  const [deployer] = await ethers.getSigners()
  const ownerAddress = deployer.address
  console.log(`Deploying ${contractName} contract with the account:`, ownerAddress)

  const Contract = await ethers.getContractFactory(contractName)
  const [contract, constructorArguments] = await callback(Contract, ownerAddress)

  await contract.waitForDeployment()

  const deployedAddress = await contract.getAddress()
  console.log(`${contractName} deployed to: ${deployedAddress}`)
  writeFileSync(`cache/${contractName}`, deployedAddress)

  console.log('Waiting for Etherscan to update the contract data...')
  // eslint-disable-next-line no-promise-executor-return
  await new Promise((resolve) => setTimeout(resolve, delay))

  // Verify the contract
  verifyContract(deployedAddress, constructorArguments)
}
