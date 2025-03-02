# DAO 智能合约系统

## 目录

- [概述](#概述)
- [核心功能](#核心功能)
- [合约架构](#合约架构)
- [部署](#部署)
- [使用场景](#使用场景)
- [安全考虑](#安全考虑)

## 概述

本项目实现了一个完整的 DAO (去中心化自治组织) 治理系统，包括投票、提案、资金管理等核心功能。系统采用模块化设计，确保了安全性和可扩展性。

## 核心功能

- 提案创建和投票
- 多签名钱包管理
- 资金池管理
- 权限控制
- 投资策略执行
- 收益分配

## 合约架构

- `Governance.sol`: 治理核心合约
- `MultiSig.sol`: 多签名钱包合约
- `Vault.sol`: 资金池合约
- `Strategy.sol`: 投资策略合约
- `AccessControl.sol`: 权限控制合约
- `ChainlinkPriceFeed.sol`: 价格预言机合约
- `ProxyAdmin.sol`: 代理管理合约

### 部署

```sh
pnpm deploy:dao
```

## 使用场景

### 场景一：创建和执行提案

**目标**: 通过 DAO 投票决定是否将资金投资到新的策略中

1. **准备工作**

```solidity
// 部署所需合约
Governance governance = new Governance();
Vault vault = new Vault();
Strategy strategy = new Strategy();

// 初始化治理代币
address governanceToken = 0x...;
governance.initialize(governanceToken, ...);
```

2. **创建提案**

```solidity
// 准备提案数据
address[] memory targets = new address[](1);
targets[0] = address(strategy);
uint256[] memory values = new uint256[](1);
values[0] = 0;
bytes[] memory calldatas = new bytes[](1);
calldatas[0] = abi.encodeWithSignature("invest(address,uint256)", token, amount);

// 创建提案
uint256 proposalId = governance.propose(
    targets,
    values,
    calldatas,
    "Invest in new yield farming strategy"
);
```

3. **投票过程**

```solidity
// 等待投票延迟期
await governance.state(proposalId) == ProposalState.Active;

// 投票支持
governance.castVote(proposalId, true);

// 或者使用带签名的投票
bytes32 digest = ...;  // 计算投票消息的哈希
(uint8 v, bytes32 r, bytes32 s) = sign(digest);
governance.castVoteBySig(proposalId, true, v, r, s);
```

4. **执行提案**

```solidity
// 检查提案是否通过
require(governance.state(proposalId) == ProposalState.Succeeded);

// 将提案加入队列
governance.queue(proposalId);

// 等待时间锁过期后执行
await block.timestamp >= proposal.eta;
governance.execute(proposalId);
```

### 场景二：多签名资金管理

**目标**: 通过多签钱包安全管理 DAO 资金

1. **初始化多签钱包**

```solidity
// 设置多签持有人和阈值
address[] memory owners = new address[](3);
owners[0] = owner1;
owners[1] = owner2;
owners[2] = owner3;
uint256 threshold = 2;  // 需要2/3签名
uint256 delay = 1 days;

MultiSig multiSig = new MultiSig(owners, threshold, delay);
```

2. **提交交易**

```solidity
// 准备交易数据
address to = recipient;
uint256 value = 1 ether;
bytes memory data = "";
uint256 gasLimit = 21000;

// 提交交易请求
uint256 txId = multiSig.submitTransaction(to, value, data, gasLimit);
```

3. **确认交易**

```solidity
// 其他持有人确认
multiSig.confirmTransaction(txId);

// 检查是否可以执行
(bool executable, string memory reason) = multiSig.isTransactionExecutable(txId);
require(executable, reason);
```

4. **执行交易**

```solidity
// 达到阈值后执行
multiSig.executeTransaction(txId);
```

### 场景三：资金池管理与收益分配

**目标**: 管理用户存款并分配收益

1. **初始化资金池**

```solidity
// 设置支持的代币
address[] memory supportedTokens = new address[](2);
supportedTokens[0] = USDC;
supportedTokens[1] = USDT;

// 初始化 Vault
vault.initialize(
    "DAO Vault",
    "vDAO",
    supportedTokens,
    accessControl
);
```

2. **用户存款**

```solidity
// 用户存入 USDC
IERC20(USDC).approve(address(vault), amount);
vault.deposit(USDC, amount);
```

3. **执行投资策略**

```solidity
// 通过策略合约进行投资
strategy.invest(USDC, investAmount);

// 收获收益
strategy.harvest();
```

4. **分配收益**

```solidity
// 更新收益池
vault.updateRewards(newRewards);

// 用户领取收益
vault.claimRewards();
```

### 场景四：权限管理

**目标**: 管理用户权限和白名单

1. **设置权限控制**

```solidity
// 初始化权限等级
bytes32 merkleRoot = 0x...;  // 白名单默克尔树根
AccessControl access = new AccessControl();
access.updateMerkleRoot(merkleRoot);
```

2. **添加用户到白名单**

```solidity
// 准备证明
bytes32[] memory proof = ...;
uint256 tier = 2;  // 用户等级

// 添加用户
access.addToWhitelist(user, tier, proof);
```

3. **设置限额**

```solidity
// 为不同等级设置限额
access.updateTierLimit(1, 1000 ether);
access.updateTierLimit(2, 5000 ether);
```

4. **权限检查**

```solidity
// 检查用户权限
require(access.isWhitelisted(user), "Not whitelisted");
require(access.checkLimit(user, amount), "Exceeds limit");
```

### 场景五：合约升级流程

**目标**: 安全地升级DAO系统中的可升级合约

1. **部署新实现合约**

```solidity
// 部署新版本的Vault实现合约
Vault vaultV2Implementation = new Vault();
```

2. **通过ProxyAdmin安排升级**

```solidity
// 安排对Vault代理的升级
bytes32 upgradeId = keccak256(abi.encodePacked(vaultProxyAddress, vaultV2Implementation));
proxyAdmin.scheduleUpgrade(vaultProxyAddress, vaultV2Implementation);
```

3. **等待时间锁过期**

```solidity
// 检查升级是否可执行
(bool isRegistered, address currentImpl, uint256 unlockTime, bool canUpgrade) =
    proxyAdmin.getUpgradeStatus(vaultProxyAddress);
require(canUpgrade, "Upgrade not ready yet");
```

4. **执行升级**

```solidity
// 执行升级
proxyAdmin.upgrade(vaultProxyAddress, vaultV2Implementation);

// 验证升级结果
address newImplementation = proxyAdmin.getImplementation(vaultProxyAddress);
require(newImplementation == address(vaultV2Implementation), "Upgrade failed");
```

### 场景六：紧急操作流程

**目标**: 在发生意外情况时保护DAO资产安全

1. **暂停合约操作**

```solidity
// 检查权限
require(vault.hasRole(msg.sender, Role.SUPER_ADMIN), "Not authorized");

// 暂停Vault操作
vault.pause();

// 暂停Strategy操作
strategy.pause();

// 暂停Governance操作
governance.pause();
```

2. **紧急取消危险提案**

```solidity
// 识别危险提案
uint256 dangerousProposalId = 42;
require(governance.state(dangerousProposalId) != ProposalState.Executed, "Already executed");

// 紧急取消
governance.emergencyCancelProposal(dangerousProposalId);
```

3. **紧急资金提取**

```solidity
// 从Strategy紧急提取所有资金到Vault
strategy.emergencyWithdraw(token);

// 从Vault紧急提取所有资金
vault.emergencyWithdraw();
```

4. **恢复操作**

```solidity
// 解决问题后恢复操作
vault.unpause();
strategy.unpause();
governance.unpause();
```

## 安全考虑

- 使用时间锁保护重要操作
- 实施多签名机制
- 限制单笔交易金额
- 防重入保护
- 权限分级管理
- 紧急暂停机制
