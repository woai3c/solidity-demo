import { expect } from 'chai'
import { ethers } from 'hardhat'
import type { MyNFT } from '../../typechain-types'
import type { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'

describe('MyNFT', () => {
  let myNFT: MyNFT
  let owner: SignerWithAddress
  let addr1: SignerWithAddress
  let addr2: SignerWithAddress

  beforeEach(async () => {
    const MyNFT = await ethers.getContractFactory('MyNFT')
    ;[owner, addr1, addr2] = await ethers.getSigners()

    myNFT = await MyNFT.deploy('MyNFT', 'MNFT', owner.address)
    await myNFT.waitForDeployment()
  })

  it('Should mint tokens correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    expect(await myNFT.balanceOf(addr1.address)).to.equal(1)
    expect(await myNFT.ownerOf(0)).to.equal(addr1.address)
  })

  it('Should mint batch tokens correctly', async () => {
    await myNFT.mintBatch([addr1.address, addr2.address], ['tokenURI1', 'tokenURI2'])
    expect(await myNFT.balanceOf(addr1.address)).to.equal(1)
    expect(await myNFT.balanceOf(addr2.address)).to.equal(1)
    expect(await myNFT.ownerOf(0)).to.equal(addr1.address)
    expect(await myNFT.ownerOf(1)).to.equal(addr2.address)
  })

  it('Should transfer tokens correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.connect(addr1).transferFrom(addr1.address, addr2.address, 0)
    expect(await myNFT.balanceOf(addr1.address)).to.equal(0)
    expect(await myNFT.balanceOf(addr2.address)).to.equal(1)
    expect(await myNFT.ownerOf(0)).to.equal(addr2.address)
  })

  it('Should approve and transferFrom tokens correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.connect(addr1).approve(addr2.address, 0)
    await myNFT.connect(addr2).transferFrom(addr1.address, addr2.address, 0)
    expect(await myNFT.balanceOf(addr1.address)).to.equal(0)
    expect(await myNFT.balanceOf(addr2.address)).to.equal(1)
    expect(await myNFT.ownerOf(0)).to.equal(addr2.address)
  })

  it('Should set approval for all correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.connect(addr1).setApprovalForAll(addr2.address, true)
    expect(await myNFT.isApprovedForAll(addr1.address, addr2.address)).to.equal(true)
  })

  it('Should burn tokens correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.connect(addr1).transferFrom(addr1.address, owner.address, 0) // Transfer to owner
    await myNFT.connect(owner).burn(0) // Owner burns the token
    expect(await myNFT.balanceOf(owner.address)).to.equal(0)
    await expect(myNFT.ownerOf(0)).to.be.revertedWithCustomError(myNFT, 'NonexistentToken')
  })

  it('Should approve and then revoke approval correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.connect(addr1).approve(addr2.address, 0)
    expect(await myNFT.getApproved(0)).to.equal(addr2.address)
    await myNFT.connect(addr1).approve(ethers.ZeroAddress, 0)
    expect(await myNFT.getApproved(0)).to.equal(ethers.ZeroAddress)
  })

  it('Should set approval for all and then revoke correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.connect(addr1).setApprovalForAll(addr2.address, true)
    expect(await myNFT.isApprovedForAll(addr1.address, addr2.address)).to.equal(true)
    await myNFT.connect(addr1).setApprovalForAll(addr2.address, false)
    expect(await myNFT.isApprovedForAll(addr1.address, addr2.address)).to.equal(false)
  })

  it('Should handle large number of tokens correctly', async () => {
    for (let i = 0; i < 100; i++) {
      await myNFT.mint(addr1.address, `tokenURI${i}`)
    }
    expect(await myNFT.balanceOf(addr1.address)).to.equal(100)
    expect(await myNFT.totalSupply()).to.equal(100)
  })

  it('Should revert transfer if not owner or approved', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await expect(myNFT.connect(addr2).transferFrom(addr1.address, addr2.address, 0)).to.be.revertedWithCustomError(
      myNFT,
      'NotAuthorized',
    )
  })

  it('Should revert mint to zero address', async () => {
    await expect(myNFT.mint(ethers.ZeroAddress, 'tokenURI1')).to.be.revertedWithCustomError(
      myNFT,
      'ZeroAddressNotAllowed',
    )
  })

  it('Should revert transfer to zero address', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await expect(myNFT.connect(addr1).transferFrom(addr1.address, ethers.ZeroAddress, 0)).to.be.revertedWithCustomError(
      myNFT,
      'ZeroAddressNotAllowed',
    )
  })

  it('Should emit Transfer event on mint', async () => {
    await expect(myNFT.mint(addr1.address, 'tokenURI1'))
      .to.emit(myNFT, 'Transfer')
      .withArgs(ethers.ZeroAddress, addr1.address, 0)
  })

  it('Should emit Transfer event on transfer', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await expect(myNFT.connect(addr1).transferFrom(addr1.address, addr2.address, 0))
      .to.emit(myNFT, 'Transfer')
      .withArgs(addr1.address, addr2.address, 0)
  })

  it('Should emit Approval event on approve', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await expect(myNFT.connect(addr1).approve(addr2.address, 0))
      .to.emit(myNFT, 'Approval')
      .withArgs(addr1.address, addr2.address, 0)
  })

  it('Should emit ApprovalForAll event on setApprovalForAll', async () => {
    await expect(myNFT.connect(addr1).setApprovalForAll(addr2.address, true))
      .to.emit(myNFT, 'ApprovalForAll')
      .withArgs(addr1.address, addr2.address, true)
  })

  it('Should emit Transfer event on burn', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.connect(addr1).transferFrom(addr1.address, owner.address, 0) // Transfer to owner
    await expect(myNFT.connect(owner).burn(0)).to.emit(myNFT, 'Transfer').withArgs(owner.address, ethers.ZeroAddress, 0)
  })

  it('Should return correct token URI', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    expect(await myNFT.tokenURI(0)).to.equal('tokenURI1')
  })

  it('Should return correct total supply', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.mint(addr2.address, 'tokenURI2')
    expect(await myNFT.totalSupply()).to.equal(2)
  })

  it('Should return correct token by index', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.mint(addr2.address, 'tokenURI2')
    expect(await myNFT.tokenByIndex(0)).to.equal(0)
    expect(await myNFT.tokenByIndex(1)).to.equal(1)
  })

  it('Should return correct token of owner by index', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.mint(addr1.address, 'tokenURI2')
    expect(await myNFT.tokenOfOwnerByIndex(addr1.address, 0)).to.equal(0)
    expect(await myNFT.tokenOfOwnerByIndex(addr1.address, 1)).to.equal(1)
  })

  it('Should support IERC165, IERC721, and IERC721Metadata interfaces', async () => {
    expect(await myNFT.supportsInterface('0x01ffc9a7')).to.equal(true) // IERC165
    expect(await myNFT.supportsInterface('0x80ac58cd')).to.equal(true) // IERC721
    expect(await myNFT.supportsInterface('0x5b5e139f')).to.equal(true) // IERC721Metadata
  })

  it('Should set and get base URI correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1') // Ensure token exists
    await myNFT.setBaseURI('https://api.example.com/')
    expect(await myNFT.tokenURI(0)).to.equal('https://api.example.com/tokenURI1')
  })

  it('Should remove token from owner enumeration correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.mint(addr1.address, 'tokenURI2')
    await myNFT.connect(addr1).transferFrom(addr1.address, addr2.address, 0)
    expect(await myNFT.tokenOfOwnerByIndex(addr1.address, 0)).to.equal(1)
  })

  it('Should approve correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    await myNFT.connect(addr1).approve(addr2.address, 0)
    expect(await myNFT.getApproved(0)).to.equal(addr2.address)
  })

  it('Should require owned token correctly', async () => {
    await myNFT.mint(addr1.address, 'tokenURI1')
    expect(await myNFT.ownerOf(0)).to.equal(addr1.address)
    await expect(myNFT.ownerOf(1)).to.be.revertedWithCustomError(myNFT, 'NonexistentToken')
  })
})
