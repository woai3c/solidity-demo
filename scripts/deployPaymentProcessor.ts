import { deployContract } from './utils'

function main() {
  return deployContract('PaymentProcessor')
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
