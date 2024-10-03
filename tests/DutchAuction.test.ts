import { expect } from 'chai'
import { ethers } from 'hardhat'
import type { DutchAuction, MyToken } from '../typechain-types'
import type { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'

describe('DutchAuction', () => {
  let myToken: MyToken
  let dutchAuction: DutchAuction
  let owner: SignerWithAddress
  let addr1: SignerWithAddress
  let addr2: SignerWithAddress

  const decimals = 6
  const tokenAmount = (amount: number) => ethers.parseUnits(amount.toString(), decimals)

  beforeEach(async () => {
    const MyToken = await ethers.getContractFactory('MyToken')
    const DutchAuction = await ethers.getContractFactory('DutchAuction')
    ;[owner, addr1, addr2] = await ethers.getSigners()

    myToken = await MyToken.deploy('MyToken', 'MTK', owner.address)
    await myToken.waitForDeployment()
    dutchAuction = await DutchAuction.deploy(await myToken.getAddress())
    await dutchAuction.waitForDeployment()

    // Mint tokens to owner and approve DutchAuction
    await myToken.mint(tokenAmount(10000))
    await myToken.approve(await dutchAuction.getAddress(), tokenAmount(10000))
  })

  it('Should configure auction correctly', async () => {
    await dutchAuction.configureAuction(tokenAmount(100), tokenAmount(50), 3600)
    const startPrice = await dutchAuction.startPrice()
    const reservePrice = await dutchAuction.reservePrice()
    const duration = await dutchAuction.duration()

    expect(startPrice).to.equal(tokenAmount(100))
    expect(reservePrice).to.equal(tokenAmount(50))
    expect(duration).to.equal(3600)
  })

  it('Should start auction correctly', async () => {
    await dutchAuction.configureAuction(tokenAmount(100), tokenAmount(50), 3600)
    await dutchAuction.startAuction()
    const startTime = await dutchAuction.startTime()
    const currentTime = await time.latest()

    expect(startTime).to.be.closeTo(currentTime, 5)
  })

  it('Should get current price correctly', async () => {
    await dutchAuction.configureAuction(tokenAmount(100), tokenAmount(50), 3600)
    await dutchAuction.startAuction()

    // Fast forward half the duration
    await time.increase(1800)
    const currentPrice = await dutchAuction.getCurrentPrice()
    expect(currentPrice).to.be.closeTo(tokenAmount(75), tokenAmount(1))
  })

  it('Should allow purchase at current price', async () => {
    await dutchAuction.configureAuction(tokenAmount(100), tokenAmount(50), 3600)
    await dutchAuction.startAuction()

    // Fast forward half the duration
    await time.increase(1800)
    const currentPrice = await dutchAuction.getCurrentPrice()

    // Mint tokens to owner and transfer to addr1
    await myToken.mint(tokenAmount(100))
    await myToken.transfer(addr1.address, tokenAmount(100))

    await myToken.connect(addr1).approve(await dutchAuction.getAddress(), currentPrice)
    await dutchAuction.connect(addr1).purchase(currentPrice)

    expect(await myToken.balanceOf(addr1.address)).to.be.closeTo(tokenAmount(100) - currentPrice, tokenAmount(1))
    expect(await myToken.balanceOf(owner.address)).to.be.closeTo(tokenAmount(10000) + currentPrice, tokenAmount(1))
  })

  it('Should revert if auction not started', async () => {
    await expect(dutchAuction.purchase(tokenAmount(100))).to.be.revertedWithCustomError(
      dutchAuction,
      'AuctionNotStarted',
    )
  })

  it('Should revert if auction was ended', async () => {
    await dutchAuction.configureAuction(tokenAmount(100), tokenAmount(50), 3600)
    await dutchAuction.startAuction()

    // Fast forward half the duration
    await time.increase(1800)
    const currentPrice = await dutchAuction.getCurrentPrice()

    // Mint tokens to owner and transfer to addr1
    await myToken.mint(tokenAmount(100))
    await myToken.transfer(addr1.address, tokenAmount(100))

    await myToken.connect(addr1).approve(await dutchAuction.getAddress(), currentPrice)
    await dutchAuction.connect(addr1).purchase(currentPrice)

    await expect(dutchAuction.connect(addr2).purchase(currentPrice)).to.be.revertedWithCustomError(
      dutchAuction,
      'AuctionWasEnded',
    )
  })

  it('Should revert if insufficient funds', async () => {
    await dutchAuction.configureAuction(tokenAmount(100), tokenAmount(50), 3600)
    await dutchAuction.startAuction()

    // Fast forward half the duration
    await time.increase(1800)

    // Mint tokens to owner and transfer to addr1
    await myToken.mint(tokenAmount(50))
    await myToken.transfer(addr1.address, tokenAmount(50))

    await myToken.connect(addr1).approve(await dutchAuction.getAddress(), tokenAmount(50))

    await expect(dutchAuction.connect(addr1).purchase(tokenAmount(50))).to.be.revertedWithCustomError(
      dutchAuction,
      'InsufficientFunds',
    )
  })

  it('Should refund excess amount', async () => {
    await dutchAuction.configureAuction(tokenAmount(100), tokenAmount(50), 3600)
    await dutchAuction.startAuction()

    // Fast forward half the duration
    await time.increase(1800)
    const currentPrice = await dutchAuction.getCurrentPrice()

    // Mint tokens to owner and transfer to addr1
    await myToken.mint(tokenAmount(100))
    await myToken.transfer(addr1.address, tokenAmount(100))

    await myToken.connect(addr1).approve(await dutchAuction.getAddress(), tokenAmount(100))
    await dutchAuction.connect(addr1).purchase(currentPrice)

    expect(await myToken.balanceOf(addr1.address)).to.be.closeTo(tokenAmount(100) - currentPrice, tokenAmount(1))
    expect(await myToken.balanceOf(owner.address)).to.be.closeTo(tokenAmount(10000) + currentPrice, tokenAmount(1))
  })
})
