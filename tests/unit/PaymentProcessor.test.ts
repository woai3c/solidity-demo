import { expect } from 'chai'
import { ethers } from 'hardhat'
import type { MyToken, PaymentProcessor } from '../../typechain-types'
import type { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { PAYMENT_CONTRACT_NAME, TOKEN_CONTRACT_NAME, TOKEN_CONTRACT_SYMBOL } from '@tests/utils/constants'

describe(PAYMENT_CONTRACT_NAME, () => {
  let myToken: MyToken
  let paymentProcessor: PaymentProcessor
  let owner: SignerWithAddress
  let addr1: SignerWithAddress

  const decimals = 6
  const tokenAmount = (amount: number) => ethers.parseUnits(amount.toString(), decimals)

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
    await myToken.mint(tokenAmount(1000))
    await myToken.transfer(addr1.address, tokenAmount(500))
    await myToken.connect(addr1).approve(await paymentProcessor.getAddress(), tokenAmount(500))
    await paymentProcessor.connect(addr1).pay(tokenAmount(500))
    expect(await myToken.balanceOf(await paymentProcessor.getAddress())).to.equal(tokenAmount(500))
  })

  it('Should withdraw tokens correctly', async () => {
    await myToken.mint(tokenAmount(1000))
    await myToken.transfer(await paymentProcessor.getAddress(), tokenAmount(500))
    await paymentProcessor.withdraw(tokenAmount(500))
    expect(await myToken.balanceOf(owner.address)).to.equal(tokenAmount(1000))
  })

  it('Should set price per liter correctly', async () => {
    await paymentProcessor.setPricePerLiter(tokenAmount(2))
    expect(await paymentProcessor.pricePerLiter()).to.equal(tokenAmount(2))
  })

  it('Should revert if insufficient balance', async () => {
    await expect(paymentProcessor.connect(addr1).pay(tokenAmount(500)))
      .to.be.revertedWithCustomError(paymentProcessor, 'InsufficientBalance')
      .withArgs(tokenAmount(0), tokenAmount(500))
  })

  it('Should revert if not owner tries to withdraw', async () => {
    await myToken.mint(tokenAmount(1000))
    await myToken.transfer(await paymentProcessor.getAddress(), tokenAmount(500))

    await expect(paymentProcessor.connect(addr1).withdraw(tokenAmount(500))).to.be.revertedWithCustomError(
      paymentProcessor,
      'OwnableUnauthorizedAccount',
    )
  })

  it('Should emit PaymentReceived event on pay', async () => {
    await myToken.mint(tokenAmount(1000))
    await myToken.transfer(addr1.address, tokenAmount(500))
    await myToken.connect(addr1).approve(await paymentProcessor.getAddress(), tokenAmount(500))
    await expect(paymentProcessor.connect(addr1).pay(tokenAmount(500)))
      .to.emit(paymentProcessor, 'PaymentReceived')
      .withArgs(addr1.address, tokenAmount(500), 500)
  })

  it('Should emit Withdrawal event on withdraw', async () => {
    await myToken.mint(tokenAmount(1000))
    await myToken.transfer(await paymentProcessor.getAddress(), tokenAmount(500))
    await expect(paymentProcessor.withdraw(tokenAmount(500)))
      .to.emit(paymentProcessor, 'Withdrawal')
      .withArgs(owner.address, tokenAmount(500))
  })

  it('Should emit PricePerLiterChanged event on setPricePerLiter', async () => {
    await expect(paymentProcessor.setPricePerLiter(tokenAmount(2)))
      .to.emit(paymentProcessor, 'PricePerLiterChanged')
      .withArgs(tokenAmount(1), tokenAmount(2))
  })

  it('Should revert withdraw if contract balance is insufficient', async () => {
    await myToken.mint(tokenAmount(1000))
    await myToken.transfer(await paymentProcessor.getAddress(), tokenAmount(500))
    await expect(paymentProcessor.withdraw(tokenAmount(1000)))
      .to.be.revertedWithCustomError(paymentProcessor, 'InsufficientBalance')
      .withArgs(tokenAmount(500), tokenAmount(1000))
  })

  it('Should update litersPurchased correctly on pay', async () => {
    await myToken.mint(tokenAmount(1000))
    await myToken.transfer(addr1.address, tokenAmount(500))
    await myToken.connect(addr1).approve(await paymentProcessor.getAddress(), tokenAmount(500))
    await paymentProcessor.connect(addr1).pay(tokenAmount(500))
    expect(await paymentProcessor.litersPurchased(addr1.address)).to.equal(500)
  })

  it('Should return correct litersPurchased for an account', async () => {
    await myToken.mint(tokenAmount(1000))
    await myToken.transfer(addr1.address, tokenAmount(500))
    await myToken.connect(addr1).approve(await paymentProcessor.getAddress(), tokenAmount(500))
    await paymentProcessor.connect(addr1).pay(tokenAmount(500))
    const litersPurchased = await paymentProcessor.litersPurchased(addr1.address)
    expect(litersPurchased).to.equal(500)
  })
})
