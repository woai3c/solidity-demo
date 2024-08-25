## 使用

### 安装依赖

```sh
pnpm i
```

### 部署合约

```sh
pnpm deploys
```

部署完成后，控制台会打印出合约的访问地址，可以在网页直接使用 `MyToken`、`PaymentProcessor` 两个合约进行交互。
### 测试
```sh
pnpm test
# 可同时查看测试覆盖率
pnpm test:coverage
```

## IERC20 协议详解

### 简介

IERC20 是以太坊上一个重要的接口标准，用于实现代币合约的功能。ERC20 全称是 "Ethereum Request for Comments 20"，而 "I" 代表 "Interface"（接口）。这个标准定义了代币合约应该实现的一系列函数和事件，以确保不同的 ERC20 代币可以在各种去中心化应用（DApps）和交易所中无缝使用。

### 核心组件

IERC20 定义了以下关键函数和事件：

#### 函数

1. `totalSupply() external view returns (uint256)`

   - 返回代币的总供应量

2. `balanceOf(address account) external view returns (uint256)`

   - 返回指定地址的代币余额

3. `transfer(address recipient, uint256 amount) external returns (bool)`

   - 转移代币到指定地址
   - 返回操作是否成功

4. `allowance(address owner, address spender) external view returns (uint256)`

   - 返回 spender 被允许从 owner 账户中提取的代币数量

5. `approve(address spender, uint256 amount) external returns (bool)`

   - 允许 spender 从调用者账户中提取指定数量的代币
   - 返回操作是否成功

6. `transferFrom(address sender, address recipient, uint256 amount) external returns (bool)`
   - 从 sender 账户转移代币到 recipient 账户（需要事先批准）
   - 返回操作是否成功

#### 事件

1. `event Transfer(address indexed from, address indexed to, uint256 value)`

   - 当代币被转移时触发

2. `event Approval(address indexed owner, address indexed spender, uint256 value)`
   - 当 approve 函数被调用时触发

### 扩展功能

除了 IERC20 标准定义的函数和事件外，合约还实现了以下两个重要的扩展功能：

#### mint

```solidity
function mint(uint256 amount) external onlyOwner
```

- 描述：铸造指定数量的代币，并将其添加到调用者的账户余额中。

#### burn

```solidity
function burn(uint256 amount) external
```

- 描述：销毁调用者账户中的指定数量的代币，并从总供应量中扣除。

注意，这些方法不是 IERC20 协议的一部分，但对于代币的发行和管理非常重要。
