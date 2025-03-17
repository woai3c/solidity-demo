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
  let attacker: MockAttacker

  async function deployTokenFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners()
    const Token = await ethers.getContractFactory('MyToken')
    const token = await Token.deploy('Test Token', 'TEST', owner.address, {
      // gasLimit: 6000000 // 可以指定gas限制
    })

    await token.waitForDeployment()
    const MockAttacker = await ethers.getContractFactory('MockAttacker')
    const attacker = await MockAttacker.deploy(await token.getAddress())
    await attacker.waitForDeployment()
    return { token, attacker, owner, addr1, addr2 }
  }

  beforeEach(async () => {
    const fixture = await loadFixture(deployTokenFixture)
    token = fixture.token
    attacker = fixture.attacker
    owner = fixture.owner
    addr1 = fixture.addr1
    addr2 = fixture.addr2
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
      // 铸造代币并转给攻击合约
      await token.mint(1000)
      await token.transfer(await attacker.getAddress(), 500)

      // 重置攻击计数
      await attacker.resetCount()

      // 验证初始计数为0
      expect(await attacker.attackCount()).to.equal(0)

      // 执行攻击
      await attacker.attack()

      // 验证攻击后计数为1
      expect(await attacker.attackCount()).to.equal(1)
    })

    it('Should enforce transfer limits', async () => {
      await token.mint(ethers.parseUnits('2000', 6))
      await expect(token.transfer(addr1.address, ethers.parseUnits('1500', 6))).to.not.be.reverted
    })

    it('Should enforce cooldown period', async () => {
      // 铸造代币
      await token.mint(1000)

      // 转账给addr1账户一些代币
      await token.transfer(addr1.address, 300)

      // 设置一个明确的冷却期
      await token.setCooldownPeriod(60) // 设置60秒冷却期

      // 让addr1执行第一次转账 (非所有者)
      await token.connect(addr1).transfer(addr2.address, 100)

      // 立即让addr1执行第二次转账 - 应该失败（冷却期内）
      await expect(token.connect(addr1).transfer(addr2.address, 100)).to.be.revertedWithCustomError(
        token,
        'CooldownPeriodNotPassed',
      )

      // 增加时间
      await time.increase(70) // 增加70秒，超过冷却期

      // 现在冷却期已过，addr1再次尝试转账 - 应该成功
      await expect(token.connect(addr1).transfer(addr2.address, 100)).to.not.be.reverted
    })

    it('Should handle blacklist correctly', async () => {
      await token.mint(1000)
      await token.updateBlacklist(addr1.address, true)

      await expect(token.transfer(addr1.address, 100)).to.be.revertedWithCustomError(token, 'BlacklistedAddress')
    })
  })
})
