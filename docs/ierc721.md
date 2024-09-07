# IERC721 协议

## 使用

### 安装依赖

```sh
pnpm i
```

### 部署合约

```sh
pnpm deploy:mynft
```

部署完成后，控制台会打印出合约的访问地址，可以在网页直接使用 `MyNFT` 合约进行交互。

### 测试

```sh
pnpm test
# 可同时查看测试覆盖率
pnpm test:coverage
```

## 协议详解

### 简介

IERC721 是以太坊上一个重要的接口标准，用于实现非同质化代币（Non-Fungible Token, NFT）合约的功能。ERC721 全称是 "Ethereum Request for Comments 721"，而 "I" 代表 "Interface"（接口）。这个标准定义了NFT合约应该实现的一系列函数和事件，以确保不同的 ERC721 代币可以在各种去中心化应用（DApps）和市场中无缝使用。

### 核心组件

IERC721 定义了以下关键函数和事件：

#### 函数

1. `balanceOf(address owner) external view returns (uint256 balance)`

   - 返回指定地址拥有的代币数量

2. `ownerOf(uint256 tokenId) external view returns (address owner)`

   - 返回指定代币ID的所有者地址

3. `safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external`

   - 安全转移代币，包含额外数据

4. `safeTransferFrom(address from, address to, uint256 tokenId) external`

   - 安全转移代币

5. `transferFrom(address from, address to, uint256 tokenId) external`

   - 转移代币

6. `approve(address to, uint256 tokenId) external`

   - 授权指定地址操作特定代币

7. `setApprovalForAll(address operator, bool approved) external`

   - 授权或撤销操作员管理所有者的所有代币

8. `getApproved(uint256 tokenId) external view returns (address operator)`

   - 获取代币的授权地址

9. `isApprovedForAll(address owner, address operator) external view returns (bool)`
   - 检查操作员是否被授权管理所有者的所有代币

#### 事件

1. `event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)`

   - 当代币被转移时触发

2. `event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)`

   - 当代币被授权时触发

3. `event ApprovalForAll(address indexed owner, address indexed operator, bool approved)`
   - 当设置或撤销操作员时触发

### 扩展功能

除了 IERC721 标准定义的函数和事件外，合约还实现了以下重要的扩展功能：

#### mint

```solidity
function mint(address to, string memory uri) public onlyOwner
```

- 描述：铸造新的NFT并分配给指定地址，同时设置代币的URI。

#### mintBatch

```solidity
function mintBatch(address[] calldata to, string[] calldata uris) external onlyOwner
```

- 描述：批量铸造NFT并分配给指定地址列表，同时设置每个代币的URI。

#### burn

```solidity
function burn(uint256 tokenId) external onlyOwner
```

- 描述：销毁指定的NFT。

#### setBaseURI

```solidity
function setBaseURI(string memory uri) public onlyOwner
```

- 描述：设置基础URI，用于构建完整的代币URI。

#### tokenURI

```solidity
function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
```

- 描述：返回指定代币ID的URI。

### 元数据扩展 (IERC721Metadata)

合约还实现了 IERC721Metadata 接口，提供了以下额外功能：

1. `name() external view returns (string memory)`

   - 返回代币集合的名称

2. `symbol() external view returns (string memory)`

   - 返回代币集合的符号

3. `tokenURI(uint256 tokenId) external view returns (string memory)`
   - 返回指定代币ID的URI

### 枚举扩展 (IERC721Enumerable)

合约实现了 IERC721Enumerable 接口，提供了以下额外功能：

1. `totalSupply() external view returns (uint256)`

   - 返回NFT的总供应量

2. `tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId)`

   - 返回指定所有者的代币列表中指定索引的代币ID

3. `tokenByIndex(uint256 index) external view returns (uint256)`
   - 返回所有代币中指定索引的代币ID

注意：这些扩展功能增强了NFT的可用性和可查询性，但不是 IERC721 标准的必需部分。
