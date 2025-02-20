import { ethers } from 'hardhat'
import { MerkleTree } from 'merkletreejs'

export interface MerkleInfo {
  root: string
  whitelist: Array<{
    address: string
    proof: string[]
  }>
}

export function generateMerkleRoot(addresses: string[]): MerkleInfo {
  // 验证地址格式
  addresses.forEach((address, index) => {
    if (!ethers.isAddress(address)) {
      throw new Error(`Invalid address format at index ${index}: ${address}`)
    }
  })

  // 创建叶子节点
  const leaves = addresses.map((addr) =>
    ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address'], [addr])),
  )

  // 创建默克尔树
  const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true })

  // 获取根哈希和证明
  return {
    root: tree.getHexRoot(),
    whitelist: addresses.map((address, i) => ({
      address,
      proof: tree.getHexProof(leaves[i]),
    })),
  }
}
