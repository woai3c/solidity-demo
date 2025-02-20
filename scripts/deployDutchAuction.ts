import { readFileSync } from 'fs'
import { deployContract } from './utils/utils'

function main() {
  const tokenAddress = readFileSync('cache/MyToken', 'utf8')
  return deployContract('DutchAuction', async (Contract) => {
    const contract = await Contract.deploy(tokenAddress)
    const constructorArguments = [tokenAddress]
    return [contract, constructorArguments]
  })
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
