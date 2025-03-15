# 使用多阶段构建减少镜像大小
FROM trailofbits/eth-security-toolbox:latest as base

# 合并RUN指令减少层数
RUN apt-get update && apt-get install -y \
    build-essential \
    python3-dev \
    curl \
    graphviz \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && solc-select install 0.8.20 \
    && solc-select use 0.8.20 \
    && pip3 install --no-cache-dir mythril \
    && npm install -g surya  

# 生成项目依赖
FROM base as dependencies
WORKDIR /deps
COPY package.json ./
RUN npm i

# 最终镜像
FROM base
WORKDIR /app

# 复制依赖和脚本 - 使用COPY代替ADD提高性能
COPY --from=dependencies /deps/node_modules /app/node_modules
COPY scripts/securityAudit.sh /app/securityAudit.sh
COPY .solhint.json ./
COPY hardhat.config.ts ./
RUN chmod +x /app/securityAudit.sh

# 设置缓存目录和命令 - 添加缓存目录加速重复审计
RUN mkdir -p /app/cache
ENV MYTHRIL_CACHE=/app/cache
ENV NODE_OPTIONS="--max-old-space-size=4096"

# 设置入口
ENTRYPOINT ["/app/securityAudit.sh"]