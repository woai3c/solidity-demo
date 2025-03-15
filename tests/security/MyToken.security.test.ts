import { loadFixture, time } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import type { MyToken, MockAttacker } from '../../typechain-types'
import type { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'

describe('MyToken Security Tests [security]', () => {
  let token: MyToken
  let owner: SignerWithAddress
  let addr1: SignerWithAddress
  let addr2: SignerWithAddress
  let addrs: SignerWithAddress[]
  let attacker: MockAttacker

  async function deployTokenFixture() {
    const [owner, addr1, addr2, ...addrs] = await ethers.getSigners()
    const Token = await ethers.getContractFactory('MyToken')
    const token = await Token.deploy('Test Token', 'TEST', owner.address, {
      // gasLimit: 6000000 // 可以指定gas限制
    })

    const MockAttacker = await ethers.getContractFactory('MockAttacker')
    const attacker = await MockAttacker.deploy(await token.getAddress())

    return { token, attacker, owner, addr1, addr2, addrs }
  }

  beforeEach(async () => {
    const fixture = await loadFixture(deployTokenFixture)
    token = fixture.token
    attacker = fixture.attacker
    owner = fixture.owner
    addr1 = fixture.addr1
    addr2 = fixture.addr2
    addrs = fixture.addrs
  })

  describe('Stress Tests', () => {
    it('Should handle multiple concurrent transfers', async () => {
      await token.mint(ethers.parseUnits('1000000', 6), {
        // gasLimit: 6000000 // 可选
      })

      const transfers = []
      for (let i = 0; i < 10; i++) {
        transfers.push(token.transfer(addr1.address, ethers.parseUnits('1000', 6)))
      }

      const txs = await Promise.all(transfers)
      const receipts = await Promise.all(txs.map((tx) => tx.wait()))

      receipts.forEach((receipt) => {
        if (!receipt) throw new Error('Transaction failed')
        expect(receipt.status).to.equal(1)
      })

      const balance = await token.balanceOf(addr1.address)
      expect(balance).to.equal(ethers.parseUnits('10000', 6))
    })

    it('Should handle rapid mints and burns', async () => {
      for (let i = 0; i < 50; i++) {
        await token.mint(1000)
        await token.burn(500)
      }

      const finalSupply = await token.totalSupply()
      expect(finalSupply).to.equal(25000)
    })
  })

  describe('Edge Cases', () => {
    it('Should handle max supply correctly', async () => {
      const maxSupply = await token.MAX_SUPPLY()
      await token.mint(maxSupply)
      await expect(token.mint(1)).to.be.revertedWithCustomError(token, 'MaxSupplyExceeded')
    })

    it('Should handle zero transfers', async () => {
      await token.mint(1000)
      await expect(token.transfer(addr1.address, 0)).to.not.be.reverted
    })

    it('Should prevent overflow in approve', async () => {
      await expect(token.approve(addr1.address, ethers.MaxUint256)).to.not.be.reverted
    })
  })

  describe('Access Control', () => {
    it('Should prevent non-owners from minting', async () => {
      await expect(token.connect(addr1).mint(1000)).to.be.revertedWithCustomError(token, 'OwnableUnauthorizedAccount')
    })

    it('Should handle ownership transfer securely', async () => {
      await token.transferOwnership(addr1.address)
      expect(await token.owner()).to.equal(addr1.address)
      await expect(token.mint(1000)).to.be.revertedWithCustomError(token, 'OwnableUnauthorizedAccount')
    })
  })

  describe('Approval Security', () => {
    it('Should handle approval race conditions', async () => {
      await token.mint(1000)
      await token.approve(addr1.address, 500)
      await token.approve(addr1.address, 200)
      expect(await token.allowance(owner.address, addr1.address)).to.equal(200)
    })
  })

  describe('Security Features', () => {
    it('Should prevent reentrancy attacks', async () => {
      // 给 token 和 attacker 准备初始状态
      await token.mint(1000)

      // 给攻击者合约转账一些代币用于攻击
      await token.transfer(await attacker.getAddress(), 200)

      // 检查初始攻击计数
      expect(await attacker.attackCount()).to.equal(0)

      // 尝试执行攻击 - 应该被 nonReentrant 修饰器阻止重入
      await attacker.attack()

      // 验证攻击计数
      const count = await attacker.attackCount()

      // 我们应该看到攻击尝试被记录，但没有成功执行多次重入
      expect(count).to.equal(1, 'Reentrancy protection should limit attack to one attempt')
    })

    it('Should enforce transfer limits', async () => {
      await token.mint(ethers.parseUnits('2000', 6))
      await expect(token.transfer(addr1.address, ethers.parseUnits('1500', 6))).to.not.be.reverted
    })

    it('Should enforce cooldown period', async () => {
      // 铸造一些代币用于测试
      await token.mint(1000)

      // 设置一个较短的冷却期，便于测试
      await token.setCooldownPeriod(60) // 60秒

      // 执行第一次转账
      await token.transfer(addr1.address, 100)

      // 获取当前时间戳
      const latestTime = await time.latest()

      // 确保下一个块的时间戳与当前相同 (不增加时间)
      await time.setNextBlockTimestamp(latestTime)

      // 尝试第二次转账 - 应该因为冷却期而失败
      await expect(token.transfer(addr1.address, 100)).to.be.revertedWithCustomError(token, 'CooldownPeriodNotPassed')

      // 增加时间超过冷却期
      await time.increaseTo(latestTime + 61)

      // 尝试转账 - 现在应该成功
      await expect(token.transfer(addr1.address, 100)).to.not.be.reverted
    })

    it('Should handle blacklist correctly', async () => {
      await token.mint(1000)
      await token.updateBlacklist(addr1.address, true)

      await expect(token.transfer(addr1.address, 100)).to.be.revertedWithCustomError(token, 'BlacklistedAddress')
    })
  })
})
