FROM trailofbits/eth-security-toolbox:latest

WORKDIR /app

# 1. 先复制依赖文件 - 利用缓存机制
COPY package.json ./
RUN npm i && \
    npm install -g surya glob

# 2. 安装系统依赖并清理 - 一次性完成减少层数
RUN apt-get update && apt-get install -y \
    build-essential python3-dev graphviz nodejs --no-install-recommends && \
    solc-select install 0.8.20 && \
    solc-select use 0.8.20 && \
    pip3 install --no-cache-dir mythril && \
    # 清理缓存减少体积
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 3. 复制很少变化的配置文件
COPY .solhintignore hardhat.config.ts audit-config.json mythril-solc.json ./

# 4. 复制可能经常变化的脚本文件
COPY scripts/securityAudit.js ./
RUN chmod +x ./securityAudit.js

# 5. 最后复制最频繁变化的合约代码
COPY contracts /app/contracts

# 配置环境
ENV NODE_OPTIONS="--max-old-space-size=8192" \
    NODE_PATH=/app/node_modules

ENTRYPOINT ["node", "/app/securityAudit.js", "/app/contracts", "/app/auditReports"]