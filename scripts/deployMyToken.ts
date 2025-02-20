import { deployContract } from './utils/utils'

function main() {
  const symbol = 'MTK'
  const contractName = 'MyToken'
  return deployContract(contractName, async (Contract, ownerAddress) => {
    const contract = await Contract.deploy(contractName, symbol, ownerAddress)
    const constructorArguments = [contractName, symbol, ownerAddress]
    return [contract, constructorArguments]
  })
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
