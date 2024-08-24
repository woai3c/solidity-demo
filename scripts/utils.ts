import { writeFileSync } from 'fs'
import { run } from 'hardhat'

export const delay = 30000

async function verifyContract(deployedAddress: string, constructorArguments: string[]) {
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

export async function deployContract(contractName: string, tokenAddress?: string) {
  const [deployer] = await ethers.getSigners()
  const ownerAddress = deployer.address
  console.log(`Deploying ${contractName} contract with the account:`, ownerAddress)

  const Contract = await ethers.getContractFactory(contractName)
  let contract
  let constructorArguments: string[] = []
  if (contractName === 'MyToken') {
    const symbol = 'MTK' // Replace with actual symbol
    contract = await Contract.deploy(contractName, symbol, ownerAddress)
    constructorArguments = [contractName, symbol, ownerAddress]
  } else {
    contract = await Contract.deploy(tokenAddress, ownerAddress)
    constructorArguments = [tokenAddress!, ownerAddress]
  }

  await contract.waitForDeployment()

  const deployedAddress = await contract.getAddress()
  console.log(`${contractName} deployed to: ${deployedAddress}`)
  writeFileSync(`cache//${contractName}`, deployedAddress)

  console.log('Waiting for Etherscan to update the contract data...')
  // eslint-disable-next-line no-promise-executor-return
  await new Promise((resolve) => setTimeout(resolve, delay))

  // Verify the contract
  verifyContract(deployedAddress, constructorArguments)
}
