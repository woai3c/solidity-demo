import { run } from 'hardhat'

export const delay = 10000
async function verifyContract(deployedAddress: string) {
  try {
    await run('verify:verify', {
      address: deployedAddress,
      constructorArguments: [],
    })

    console.log('Contract verified successfully')
  } catch (error) {
    console.error('Error verifying the contract:', error)
    setTimeout(() => verifyContract(deployedAddress), delay)
  }
}

export async function deployContract(contractName: string) {
  const [deployer] = await ethers.getSigners()
  console.log('Deploying PaymentProcessor contract with the account:', deployer.address)

  const PaymentProcessor = await ethers.getContractFactory(contractName)
  const paymentProcessor = await PaymentProcessor.deploy()
  await paymentProcessor.waitForDeployment()

  const deployedAddress = await paymentProcessor.getAddress()
  console.log(`${contractName} deployed to: ${deployedAddress}`)

  console.log('Waiting for Etherscan to update the contract data...')
  // eslint-disable-next-line no-promise-executor-return
  await new Promise((resolve) => setTimeout(resolve, delay))

  // Verify the contract
  verifyContract(deployedAddress)
}
