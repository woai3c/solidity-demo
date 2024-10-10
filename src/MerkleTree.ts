import { createHash } from 'crypto'

class MerkleTree {
  private leaves: string[]
  private tree: string[][]

  constructor(leaves: string[]) {
    this.leaves = leaves.map((data) => this.hash(data))
    this.tree = this.buildTree(this.leaves)
  }

  // 使用 SHA-256 进行哈希
  private hash(data: string): string {
    return createHash('sha256').update(data).digest('hex')
  }

  // 构建默克尔树
  private buildTree(leaves: string[]): string[][] {
    if (leaves.length === 1) {
      return [leaves] // 返回叶子层
    }

    const treeLevel: string[] = []
    for (let i = 0; i < leaves.length; i += 2) {
      const left = leaves[i]
      const right = leaves[i + 1] || left // 如果是奇数节点，复制左节点
      const hash = this.hash(left + right)
      treeLevel.push(hash)
    }

    return [leaves, ...this.buildTree(treeLevel)]
  }

  // 获取根节点
  public getRoot(): string {
    return this.tree[this.tree.length - 1][0] // 返回树的最后一层的第一个元素
  }

  // 获取证明路径
  public getProof(leaf: string): string[] {
    const leafHash = this.hash(leaf)
    let index = this.leaves.indexOf(leafHash)
    if (index === -1) {
      throw new Error('Leaf not found in tree')
    }

    const proof: string[] = []
    for (let i = 0; i < this.tree.length - 1; i++) {
      const level = this.tree[i]
      const isRightNode = index % 2
      const pairIndex = isRightNode ? index - 1 : index + 1

      if (pairIndex < level.length) {
        proof.push(level[pairIndex])
      }

      index = Math.floor(index / 2)
    }

    return proof
  }

  // 验证证明
  public verifyProof(leaf: string, proof: string[], root: string): boolean {
    let hash = this.hash(leaf)

    for (const siblingHash of proof) {
      // 假设 `proof` 按照给定的顺序正确地从叶子节点到根节点排列
      hash = this.hash(hash + siblingHash) // 拼接时固定顺序，先左再右
    }

    return hash === root
  }
}

// 示例使用
const leaves = ['a', 'b', 'c', 'd']
const merkleTree = new MerkleTree(leaves)
console.log('Merkle Tree:', merkleTree)
const root = merkleTree.getRoot()
console.log('Merkle Root:', root)

const leaf = 'a'
const proof = merkleTree.getProof(leaf)
console.log('Proof for leaf "a":', proof)

const isValid = merkleTree.verifyProof(leaf, proof, root)
console.log('Is valid proof:', isValid)
