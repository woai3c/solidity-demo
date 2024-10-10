import { ec as EC } from 'elliptic'
import { createHash } from 'crypto'

const ec = new EC('secp256k1') // 使用 secp256k1 椭圆曲线

// 生成密钥对
const keyPair = ec.genKeyPair()
const privateKey = keyPair.getPrivate('hex')
const publicKey = keyPair.getPublic('hex')

console.log('Private Key:', privateKey)
console.log('Public Key:', publicKey)

const data: string = 'Hello, ECDSA!'

// 计算数据的哈希值
const hash = createHash('sha256').update(data).digest('hex')

// 使用私钥生成签名
const signature = keyPair.sign(hash, 'hex')
const signatureHex = signature
  .toDER()
  .map((byte) => byte.toString(16).padStart(2, '0'))
  .join('')

console.log('Signature:', signatureHex)

// 使用公钥验证签名
const isValid = ec.keyFromPublic(publicKey, 'hex').verify(hash, signature)

console.log('Is valid signature:', isValid)
