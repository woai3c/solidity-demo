import { deployContract } from './utils'

function main() {
  return deployContract('MyToken')
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
