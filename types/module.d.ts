declare module 'elliptic' {
  import type BN from 'bn.js'

  namespace elliptic {
    namespace ec {
      interface SignatureInput {
        r: BN
        s: BN
        recoveryParam?: number | null
      }

      interface Signature {
        r: BN
        s: BN
        recoveryParam: number | null
        toDER(): number[]
      }

      interface KeyPair {
        getPrivate(enc?: 'hex'): string
        getPublic(enc?: 'hex'): string
        sign(msg: BN | Buffer | string, enc?: 'hex', options?: { canonical?: boolean }): Signature
        verify(msg: BN | Buffer | string, signature: SignatureInput): boolean
      }

      interface EC {
        genKeyPair(options?: { entropy?: Buffer; entropyEnc?: string; pers?: string; persEnc?: string }): KeyPair
        keyFromPrivate(priv: BN | Buffer | string, enc?: 'hex'): KeyPair
        keyFromPublic(pub: BN | Buffer | string, enc?: 'hex'): KeyPair
        sign(msg: BN | Buffer | string, key: KeyPair, enc?: 'hex', options?: { canonical?: boolean }): Signature
        verify(msg: BN | Buffer | string, signature: SignatureInput, key: KeyPair): boolean
      }
    }
  }

  const elliptic: {
    ec: new (curve: string) => elliptic.ec.EC
  }

  export = elliptic
}
