import { readFileSync } from 'fs'
import { deployContract } from './utils/utils'

function main() {
  const tokenAddress = readFileSync('cache/MyToken', 'utf8')
  const initialDistributionAmount = 1000000
  return deployContract('Faucet', async (Contract, ownerAddress) => {
    const contract = await Contract.deploy(tokenAddress, ownerAddress, initialDistributionAmount)
    const constructorArguments = [tokenAddress, ownerAddress, initialDistributionAmount]
    return [contract, constructorArguments]
  })
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
