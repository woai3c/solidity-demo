import type { ContractTransactionResponse } from 'ethers'

export interface BaseContract {
  transferOwnership(newOwner: string): Promise<ContractTransactionResponse>
  waitForDeployment(): Promise<void>
  getAddress(): Promise<string>
}

export interface IVault extends BaseContract {
  setGovernance(governance: string): Promise<ContractTransactionResponse>
  setStrategy(strategy: string): Promise<ContractTransactionResponse>
  setAccessControl(accessControl: string): Promise<ContractTransactionResponse>
}

export interface IStrategy extends BaseContract {}

export interface IGovernance extends BaseContract {}
