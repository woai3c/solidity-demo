import { expect } from 'chai'
import { ethers } from 'hardhat'
import type { MyToken, PaymentProcessor } from '../typechain-types'
import type { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { PAYMENT_CONTRACT_NAME, TOKEN_CONTRACT_NAME, TOKEN_CONTRACT_SYMBOL } from '@tests/constants'

describe(PAYMENT_CONTRACT_NAME, () => {
  let myToken: MyToken
  let paymentProcessor: PaymentProcessor
  let owner: SignerWithAddress
  let addr1: SignerWithAddress

  beforeEach(async () => {
    const MyToken = await ethers.getContractFactory(TOKEN_CONTRACT_NAME)
    const PaymentProcessor = await ethers.getContractFactory(PAYMENT_CONTRACT_NAME)
    ;[owner, addr1] = await ethers.getSigners()

    myToken = await MyToken.deploy(TOKEN_CONTRACT_NAME, TOKEN_CONTRACT_SYMBOL, owner.address)
    await myToken.waitForDeployment()
    paymentProcessor = await PaymentProcessor.deploy(await myToken.getAddress(), owner.address)
    await paymentProcessor.waitForDeployment()
  })

  it('Should process payments correctly', async () => {
    await myToken.mint(1000)
    await myToken.transfer(addr1.address, 500)
    await myToken.connect(addr1).approve(await paymentProcessor.getAddress(), 500)
    await paymentProcessor.connect(addr1).pay(500)
    expect(await myToken.balanceOf(await paymentProcessor.getAddress())).to.equal(500)
  })

  it('Should withdraw tokens correctly', async () => {
    await myToken.mint(1000)
    await myToken.transfer(await paymentProcessor.getAddress(), 500)
    await paymentProcessor.withdraw(500)
    expect(await myToken.balanceOf(owner.address)).to.equal(1000)
  })

  it('Should set price per liter correctly', async () => {
    await paymentProcessor.setPricePerLiter(2)
    expect(await paymentProcessor.pricePerLiter()).to.equal(2)
  })

  it('Should revert if insufficient balance', async () => {
    await expect(paymentProcessor.connect(addr1).pay(500))
      .to.be.revertedWithCustomError(paymentProcessor, 'InsufficientBalance')
      .withArgs(0, 500)
  })

  it('Should revert if not owner tries to withdraw', async () => {
    await myToken.mint(1000)
    await myToken.transfer(await paymentProcessor.getAddress(), 500)

    await expect(paymentProcessor.connect(addr1).withdraw(500)).to.be.revertedWithCustomError(
      paymentProcessor,
      'OwnableUnauthorizedAccount',
    )
  })

  it('Should emit PaymentReceived event on pay', async () => {
    await myToken.mint(1000)
    await myToken.transfer(addr1.address, 500)
    await myToken.connect(addr1).approve(await paymentProcessor.getAddress(), 500)
    await expect(paymentProcessor.connect(addr1).pay(500))
      .to.emit(paymentProcessor, 'PaymentReceived')
      .withArgs(addr1.address, 500, 500)
  })

  it('Should emit Withdrawal event on withdraw', async () => {
    await myToken.mint(1000)
    await myToken.transfer(await paymentProcessor.getAddress(), 500)
    await expect(paymentProcessor.withdraw(500)).to.emit(paymentProcessor, 'Withdrawal').withArgs(owner.address, 500)
  })

  it('Should emit PricePerLiterChanged event on setPricePerLiter', async () => {
    await expect(paymentProcessor.setPricePerLiter(2)).to.emit(paymentProcessor, 'PricePerLiterChanged').withArgs(1, 2)
  })

  it('Should revert withdraw if contract balance is insufficient', async () => {
    await myToken.mint(1000)
    await myToken.transfer(await paymentProcessor.getAddress(), 500)
    await expect(paymentProcessor.withdraw(1000))
      .to.be.revertedWithCustomError(paymentProcessor, 'InsufficientBalance')
      .withArgs(500, 1000)
  })
})
