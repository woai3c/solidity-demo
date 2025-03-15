import { expect } from 'chai'
import { ethers } from 'hardhat'
import { ZeroAddress } from 'ethers'
import type { MyToken } from '../../typechain-types'
import type { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { TOKEN_CONTRACT_NAME, TOKEN_CONTRACT_SYMBOL } from '@tests/unit/constants'

describe(TOKEN_CONTRACT_NAME, () => {
  let myToken: MyToken
  let owner: SignerWithAddress
  let addr1: SignerWithAddress
  let addr2: SignerWithAddress

  beforeEach(async () => {
    const MyToken = await ethers.getContractFactory(TOKEN_CONTRACT_NAME)
    ;[owner, addr1, addr2] = await ethers.getSigners()

    myToken = await MyToken.deploy(TOKEN_CONTRACT_NAME, TOKEN_CONTRACT_SYMBOL, owner.address)
    await myToken.waitForDeployment()
  })

  it('Should mint tokens correctly', async () => {
    await myToken.mint(1000)
    expect(await myToken.balanceOf(owner.address)).to.equal(1000)
    expect(await myToken.totalSupply()).to.equal(1000)
  })

  it('Should transfer tokens correctly', async () => {
    await myToken.mint(1000)
    await myToken.transfer(addr1.address, 500)
    expect(await myToken.balanceOf(owner.address)).to.equal(500)
    expect(await myToken.balanceOf(addr1.address)).to.equal(500)
  })

  it('Should approve and transferFrom tokens correctly', async () => {
    await myToken.mint(1000)
    await myToken.approve(addr1.address, 500)
    await myToken.connect(addr1).transferFrom(owner.address, addr2.address, 500)
    expect(await myToken.balanceOf(owner.address)).to.equal(500)
    expect(await myToken.balanceOf(addr2.address)).to.equal(500)
    expect(await myToken.allowance(owner.address, addr1.address)).to.equal(0)
  })

  it('Should burn tokens correctly', async () => {
    await myToken.mint(1000)
    await myToken.burn(500)
    expect(await myToken.balanceOf(owner.address)).to.equal(500)
    expect(await myToken.totalSupply()).to.equal(500)
  })

  it('Should revert transfer if balance is insufficient', async () => {
    await expect(myToken.transfer(addr1.address, 500))
      .to.be.revertedWithCustomError(myToken, 'InsufficientBalance')
      .withArgs(0, 500)
  })

  it('Should revert transferFrom if balance is insufficient', async () => {
    await myToken.mint(1000)
    await myToken.approve(addr1.address, 500)
    await expect(myToken.connect(addr1).transferFrom(owner.address, addr2.address, 1500))
      .to.be.revertedWithCustomError(myToken, 'InsufficientBalance')
      .withArgs(1000, 1500)
  })

  it('Should revert transferFrom if allowance is insufficient', async () => {
    await myToken.mint(1000)
    await myToken.approve(addr1.address, 500)
    await expect(myToken.connect(addr1).transferFrom(owner.address, addr2.address, 1000))
      .to.be.revertedWithCustomError(myToken, 'AllowanceExceeded')
      .withArgs(500, 1000)
  })

  it('Should update allowance correctly', async () => {
    await myToken.approve(addr1.address, 500)
    expect(await myToken.allowance(owner.address, addr1.address)).to.equal(500)
  })

  it('Should emit Transfer event on mint', async () => {
    await expect(myToken.mint(1000)).to.emit(myToken, 'Transfer').withArgs(ZeroAddress, owner.address, 1000)
  })

  it('Should emit Transfer event on transfer', async () => {
    await myToken.mint(1000)
    await expect(myToken.transfer(addr1.address, 500))
      .to.emit(myToken, 'Transfer')
      .withArgs(owner.address, addr1.address, 500)
  })

  it('Should emit Transfer event on burn', async () => {
    await myToken.mint(1000)
    await expect(myToken.burn(500)).to.emit(myToken, 'Transfer').withArgs(owner.address, ZeroAddress, 500)
  })

  it('Should emit Approval event on approve', async () => {
    await expect(myToken.approve(addr1.address, 500))
      .to.emit(myToken, 'Approval')
      .withArgs(owner.address, addr1.address, 500)
  })

  it('Should revert burn if balance is insufficient', async () => {
    await expect(myToken.burn(500)).to.be.revertedWithCustomError(myToken, 'InsufficientBalance').withArgs(0, 500)
  })
})
