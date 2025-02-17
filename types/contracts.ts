import type { Contract } from 'ethers'

export interface IVault extends Contract {
  setGovernance(governance: string): Promise<any>
  setStrategy(strategy: string): Promise<any>
  setAccessControl(accessControl: string): Promise<any>
  transferOwnership(newOwner: string): Promise<any>
}

export interface IStrategy extends Contract {
  transferOwnership(newOwner: string): Promise<any>
}

export interface IGovernance extends Contract {
  transferOwnership(newOwner: string): Promise<any>
}
