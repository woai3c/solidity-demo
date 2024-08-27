# 水龙头合约

## 使用

### 安装依赖

```sh
pnpm i
```

### 部署合约

```sh
pnpm deploy:mytoken
pnpm deploy:faucet
```

部署完成后，控制台会打印出合约的访问地址，可以在网页直接使用 `Faucet` 合约测试一下领取代币。

### 测试

```sh
pnpm test
# 可同时查看测试覆盖率
pnpm test:coverage
```
