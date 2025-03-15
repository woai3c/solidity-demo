import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import type { MyToken } from '../../typechain-types'
import type { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'

describe('MyToken Gas Tests [gas]', () => {
  let token: MyToken
  let owner: SignerWithAddress
  let addr1: SignerWithAddress
  let addr2: SignerWithAddress

  async function deployTokenFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners()
    const Token = await ethers.getContractFactory('MyToken')
    const token = await Token.deploy('Test Token', 'TEST', owner.address)
    return { token, owner, addr1, addr2 }
  }

  beforeEach(async () => {
    const fixture = await loadFixture(deployTokenFixture)
    token = fixture.token
    owner = fixture.owner
    addr1 = fixture.addr1
    addr2 = fixture.addr2
  })

  describe('Basic Operations Gas', () => {
    it('Should optimize mint gas usage', async () => {
      const tx = await token.mint(1000)
      const receipt = await tx.wait()
      if (!receipt) throw new Error('Transaction failed')
      console.log('Mint gas used:', receipt.gasUsed)
      expect(receipt.gasUsed).to.be.below(100000)
    })

    it('Should optimize transfer gas usage', async () => {
      await token.mint(1000)
      const tx = await token.transfer(addr1.address, 100)
      const receipt = await tx.wait()
      if (!receipt) throw new Error('Transaction failed')
      console.log('Transfer gas used:', receipt.gasUsed)
      expect(receipt.gasUsed).to.be.below(85000)
    })

    it('Should optimize approve gas usage', async () => {
      const tx = await token.approve(addr1.address, 1000)
      const receipt = await tx.wait()
      if (!receipt) throw new Error('Transaction failed')
      console.log('Approve gas used:', receipt.gasUsed)
      expect(receipt.gasUsed).to.be.below(50000)
    })

    it('Should optimize burn gas usage', async () => {
      await token.mint(1000)
      const tx = await token.burn(500)
      const receipt = await tx.wait()
      if (!receipt) throw new Error('Transaction failed')
      console.log('Burn gas used:', receipt.gasUsed)
      expect(receipt.gasUsed).to.be.below(60000)
    })
  })

  describe('Complex Operations Gas', () => {
    it('Should optimize batch transfers gas usage', async () => {
      await token.mint(10000)

      const batchSize = 5
      const transfers = []
      for (let i = 0; i < batchSize; i++) {
        transfers.push(token.transfer(addr1.address, 100))
      }

      const txs = await Promise.all(transfers)
      const receipts = await Promise.all(txs.map((tx) => tx.wait()))

      receipts.forEach((receipt, index) => {
        if (!receipt) throw new Error('Transaction failed')
        console.log(`Batch transfer ${index + 1} gas used:`, receipt.gasUsed)
        expect(receipt.gasUsed).to.be.below(85000)
      })
    })

    it('Should optimize transferFrom gas usage', async () => {
      await token.mint(1000)
      await token.approve(addr1.address, 500)

      const tx = await token.connect(addr1).transferFrom(owner.address, addr2.address, 300)
      const receipt = await tx.wait()
      if (!receipt) throw new Error('Transaction failed')
      console.log('TransferFrom gas used:', receipt.gasUsed)
      expect(receipt.gasUsed).to.be.below(90000)
    })
  })
})
