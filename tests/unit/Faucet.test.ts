import { expect } from 'chai'
import { ethers } from 'hardhat'
import type { MyToken, Faucet } from '../../typechain-types'
import type { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { FAUCET_CONTRACT_NAME, TOKEN_CONTRACT_NAME, TOKEN_CONTRACT_SYMBOL } from '@tests/unit/constants'
import { time } from '@nomicfoundation/hardhat-network-helpers'

describe(FAUCET_CONTRACT_NAME, () => {
  let myToken: MyToken
  let faucet: Faucet
  let owner: SignerWithAddress
  let addr1: SignerWithAddress
  let addr2: SignerWithAddress

  const decimals = 6
  const tokenAmount = (amount: number) => ethers.parseUnits(amount.toString(), decimals)

  beforeEach(async () => {
    const MyToken = await ethers.getContractFactory(TOKEN_CONTRACT_NAME)
    const Faucet = await ethers.getContractFactory(FAUCET_CONTRACT_NAME)
    ;[owner, addr1, addr2] = await ethers.getSigners()

    myToken = await MyToken.deploy(TOKEN_CONTRACT_NAME, TOKEN_CONTRACT_SYMBOL, owner.address)
    await myToken.waitForDeployment()
    faucet = await Faucet.deploy(await myToken.getAddress(), owner.address, tokenAmount(100))
    await faucet.waitForDeployment()

    // Mint tokens to owner and approve faucet
    await myToken.mint(tokenAmount(10000))
    await myToken.approve(await faucet.getAddress(), tokenAmount(10000))
  })

  it('Should distribute tokens correctly', async () => {
    await faucet.distributeToken(addr1.address)
    expect(await myToken.balanceOf(addr1.address)).to.equal(tokenAmount(100))
  })

  it('Should not distribute tokens within distribution interval', async () => {
    await faucet.distributeToken(addr1.address)
    await expect(faucet.distributeToken(addr1.address)).to.be.revertedWithCustomError(faucet, 'AlreadyDistributedInDay')
  })

  it('Should revert if recipient is zero address', async () => {
    await expect(faucet.distributeToken(ethers.ZeroAddress)).to.be.revertedWithCustomError(faucet, 'InvalidRecipient')
  })

  it('Should revert if owner has insufficient balance', async () => {
    await faucet.setDistributionAmount(tokenAmount(10001))
    await expect(faucet.distributeToken(addr1.address)).to.be.revertedWithCustomError(faucet, 'InsufficientBalance')
  })

  it('Should set distribution amount correctly', async () => {
    await faucet.setDistributionAmount(tokenAmount(200))
    expect(await faucet.distributionAmount()).to.equal(tokenAmount(200))
  })

  it('Should emit DistributionAmountChanged event', async () => {
    await expect(faucet.setDistributionAmount(tokenAmount(200)))
      .to.emit(faucet, 'DistributionAmountChanged')
      .withArgs(tokenAmount(100), tokenAmount(200))
  })

  it('Should pause and unpause the contract', async () => {
    await faucet.pause()
    expect(await faucet.isPaused()).to.be.true

    await faucet.unpause()
    expect(await faucet.isPaused()).to.be.false
  })

  it('Should not distribute tokens when paused', async () => {
    await faucet.pause()
    await expect(faucet.distributeToken(addr1.address)).to.be.revertedWithCustomError(faucet, 'ContractPaused')
  })

  it('Should emit FaucetPaused and FaucetUnpaused events', async () => {
    await expect(faucet.pause()).to.emit(faucet, 'FaucetPaused').withArgs(owner.address)

    await expect(faucet.unpause()).to.emit(faucet, 'FaucetUnpaused').withArgs(owner.address)
  })

  it('Should not allow non-owners to distribute tokens', async () => {
    await expect(faucet.connect(addr1).distributeToken(addr2.address)).to.be.revertedWithCustomError(
      faucet,
      'OwnableUnauthorizedAccount',
    )
  })

  it('Should update lastDistributionTime correctly', async () => {
    await faucet.distributeToken(addr1.address)
    const lastTime = await faucet.lastDistributionTime(addr1.address)
    const currentTime = await time.latest()
    expect(lastTime).to.be.closeTo(currentTime, 5)
  })
})
