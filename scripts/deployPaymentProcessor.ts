import { readFileSync } from 'fs'
import { deployContract } from './utils'

function main() {
  return deployContract('PaymentProcessor', readFileSync('cache/MyToken', 'utf8'))
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
