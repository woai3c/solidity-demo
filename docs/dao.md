# 去中心化自治组织(DAO)

## 项目概述

基于智能合约的去中心化投资基金，允许用户通过存入加密资产获得治理代币，共同参与投资决策和收益分配。系统包含资金池管理、多签钱包、治理系统等核心模块。

# 去中心化自治组织(DAO)

## 架构概述

本 DAO 项目采用模块化设计，主要包含以下核心组件：

### 1. 访问控制 (AccessControl.sol)

- 基于默克尔树的白名单系统
- 分级权限控制(Tier 1-4)
- 用户限额管理
- 紧急暂停机制

### 2. 资金库 (Vault.sol)

- ERC20 代币管理
- 存取款业务逻辑
- 收益分配系统
- 费用管理
- 与 Chainlink 预言机集成的价格发现

### 3. 治理系统 (Governance.sol)

- 提案创建与投票
- 时间锁定机制
- 委托投票
- 紧急取消机制

### 4. 多签钱包 (MultiSig.sol)

- 交易提交与确认
- 角色分级(SUPER_ADMIN/ADMIN/BASIC)
- 紧急处理机制
- 交易执行超时保护

### 5. 投资策略 (Strategy.sol)

- 自动化投资逻辑
- 资产再平衡
- 收益收割
- 风险控制

### 2. 部署流程

```sh
pnpm deploy:dao
```

## 使用场景示例

### 场景1: 创建投资提案

```javascript
// 1. 准备提案数据
const targets = [strategy.address]
const values = [0]
const calldatas = [strategy.interface.encodeFunctionData('invest', [token.address, ethers.utils.parseEther('1000')])]
const description = 'Invest 1000 USDC in Lending Protocol'

// 2. 提交提案
await governance.propose(targets, values, calldatas, description)
const proposalId = await governance.proposalCount()

// 3. 等待投票延迟
await network.provider.send('evm_increaseTime', [votingDelay])

// 4. 投票
await governance.castVote(proposalId, true)

// 5. 等待投票期结束
await network.provider.send('evm_increaseTime', [votingPeriod])

// 6. 执行提案
await governance.execute(proposalId)
```

### 场景2: 多签钱包资金转移

```javascript
// 1. 提交转账交易
const to = '0x...'
const value = ethers.utils.parseEther('10')
const data = '0x'
await multiSig.submitTransaction(to, value, data)
const txId = (await multiSig.transactionCount()) - 1

// 2. 其他签名者确认
await multiSig.connect(signer2).confirmTransaction(txId)
await multiSig.connect(signer3).confirmTransaction(txId)

// 3. 达到阈值后自动执行
// 或手动执行
await multiSig.executeTransaction(txId)
```

### 场景3: 紧急情况处理

```javascript
// 1. 暂停所有操作
await vault.pause()

// 2. 紧急提款
await vault.emergencyWithdraw()

// 3. 取消待执行的提案
await governance.cancelProposal(proposalId)

// 4. 恢复操作
await vault.unpause()
```

## 安全机制

1. 时间锁定

- 提案执行延迟: 2-14 天
- 多签交易确认等待期: 24 小时
- 升级冷却期: 48 小时

2. 权限分级

```solidity
enum Role {
  BASIC,
  ADMIN,
  SUPER_ADMIN
}
```

3. 交易限额

```solidity
mapping(uint256 => uint256) public tierLimits;
```

4. 多重签名

- 交易执行需要达到指定确认数
- 重要操作需要高级角色确认

5. 紧急暂停

- 所有合约都继承 Pausable
- 可以快速冻结危险操作

## 接口规范

### IPriceFeed

价格预言机接口

```solidity
interface IPriceFeed {
  function getPrice(address token) external view returns (uint256);
  function addPriceFeed(address token, address feed) external;
}
```

### IStrategy

投资策略接口

```solidity
interface IStrategy {
  function invest(address token, uint256 amount) external returns (bool);
  function withdraw(address token, uint256 amount) external returns (bool);
  function harvest() external returns (uint256 totalValue);
}
```

## 测试用例

```typescript
describe("Vault", () => {
  it("should deposit tokens and mint shares", async () => {
    const amount = ethers.utils.parseEther("100");
    await token.approve(vault.address, amount);
    await vault.depositToken(token.address, amount);

    const shares = await vault.balanceOf(user.address);
    expect(shares).to.gt(0);
  });
});

describe("Governance", () => {
  it("should execute successful proposal", async () => {
    // 创建提案
    await governance.propose(...);

    // 投票
    await governance.castVote(proposalId, true);

    // 检查状态
    expect(await governance.state(proposalId)).to.equal(4); // Executed
  });
});
```

## 升级机制

合约采用 UUPS 代理模式，支持安全升级：

```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
  // 验证新实现合约
  if (!_isContract(newImplementation)) revert InvalidImplementation();
  // 其他验证...
}
```
