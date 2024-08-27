import { readFileSync } from 'fs'
import { deployContract } from './utils'

function main() {
  const tokenAddress = readFileSync('cache/MyToken', 'utf8')
  return deployContract('PaymentProcessor', async (Contract, ownerAddress) => {
    const contract = await Contract.deploy(tokenAddress, ownerAddress)
    const constructorArguments = [tokenAddress, ownerAddress]
    return [contract, constructorArguments]
  })
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
