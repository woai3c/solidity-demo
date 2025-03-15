#!/bin/bash

set +e

# 定义颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 参数
CONTRACT_DIR=${1:-"/share/contracts"}
OUTPUT_DIR=${2:-"/share/auditReports"}
CONTRACT_FILE=${3:-"MyToken.sol"}
CONTRACT_NAME=${4:-"MyToken"}
SKIP_MYTHRIL=${5:-"false"}  # 添加跳过Mythril的选项

# 创建输出目录
mkdir -p $OUTPUT_DIR

echo -e "${BLUE}开始智能合约安全审计...${NC}"
echo -e "${BLUE}使用Solidity版本: $(solc --version | head -n1)${NC}"

# 创建临时工作目录和缓存目录
TEMP_DIR="/tmp/audit-work"
CACHE_DIR="/app/cache"
mkdir -p $TEMP_DIR/contracts
mkdir -p $TEMP_DIR/node_modules
mkdir -p $CACHE_DIR

# 复制合约文件
cp $CONTRACT_DIR/$CONTRACT_FILE $TEMP_DIR/contracts/
echo -e "${GREEN}已复制合约文件到临时目录${NC}"

# 检查缓存 - 添加缓存机制
CACHE_KEY=$(md5sum $CONTRACT_DIR/$CONTRACT_FILE | awk '{print $1}')
if [ -f "$CACHE_DIR/$CACHE_KEY.slither.json" ]; then
    echo -e "${GREEN}使用缓存的Slither分析结果${NC}"
    cp "$CACHE_DIR/$CACHE_KEY.slither.json" "$OUTPUT_DIR/slither-results.json"
    SKIP_SLITHER="true"
else
    SKIP_SLITHER="false"
fi

# 复制node_modules (优先使用容器内已安装的)
if [ -d "/app/node_modules/@openzeppelin" ]; then
    echo -e "${GREEN}使用容器内的OpenZeppelin合约${NC}"
    cp -r /app/node_modules/@openzeppelin $TEMP_DIR/node_modules/
elif [ -d "/share/node_modules/@openzeppelin" ]; then
    echo -e "${GREEN}使用宿主机的OpenZeppelin合约${NC}"
    cp -r /share/node_modules/@openzeppelin $TEMP_DIR/node_modules/
else
    echo -e "${RED}未找到OpenZeppelin合约，尝试安装...${NC}"
    cd $TEMP_DIR
    npm init -y
    npm install @openzeppelin/contracts@5.1.0
fi

# 修改合约导入路径为相对路径
cd $TEMP_DIR
sed -i 's|@openzeppelin/contracts|../node_modules/@openzeppelin/contracts|g' contracts/$CONTRACT_FILE

# 复制配置文件到临时目录
echo -e "${GREEN}复制配置文件到临时目录...${NC}"

# 复制 .solhint.json 配置文件
if [ -f "/app/.solhint.json" ]; then
    cp /app/.solhint.json $TEMP_DIR/
    echo -e "${GREEN}已复制 .solhint.json 配置${NC}"
elif [ -f "/share/.solhint.json" ]; then
    cp /share/.solhint.json $TEMP_DIR/
    echo -e "${GREEN}已复制 .solhint.json 配置${NC}"
else
    echo -e "${YELLOW}未找到 .solhint.json 配置文件${NC}"
fi

# 复制 hardhat.config.ts
if [ -f "/app/hardhat.config.ts" ]; then
    cp /app/hardhat.config.ts $TEMP_DIR/
    echo -e "${GREEN}已复制 hardhat.config.ts 配置${NC}"
elif [ -f "/share/hardhat.config.ts" ]; then
    cp /share/hardhat.config.ts $TEMP_DIR/
    echo -e "${GREEN}已复制 hardhat.config.ts 配置${NC}"
else
    echo -e "${YELLOW}未找到 hardhat.config.ts 配置文件${NC}"
fi

# Slither 分析 - 添加缓存
if [ "$SKIP_SLITHER" = "false" ]; then
    echo -e "${GREEN}运行 Slither 分析...${NC}"
    cd $TEMP_DIR

    # 检查是否有配置文件
    if [ -f "/share/audit-config.json" ]; then
        cp "/share/audit-config.json" ./
        echo -e "${GREEN}使用配置文件运行Slither${NC}"
        slither contracts/$CONTRACT_FILE --json $OUTPUT_DIR/slither-results.json --config-file audit-config.json || {
            echo -e "${YELLOW}Slither分析完成，发现了一些安全问题${NC}"
            true
        }
    else
        slither contracts/$CONTRACT_FILE --json $OUTPUT_DIR/slither-results.json || {
            echo -e "${YELLOW}Slither分析完成，发现了一些安全问题${NC}"
            true
        }
    fi

    if [ -f "$OUTPUT_DIR/slither-results.json" ]; then
        echo -e "${GREEN}Slither分析完成 - 结果已保存${NC}"
        # 保存缓存
        cp "$OUTPUT_DIR/slither-results.json" "$CACHE_DIR/$CACHE_KEY.slither.json"
    else
        echo -e "${RED}Slither分析失败 - 未能生成报告${NC}"
    fi
fi

# Mythril 分析 - 添加超时和跳过选项
if [ "$SKIP_MYTHRIL" = "false" ]; then
    echo -e "${GREEN}运行 Mythril 分析 (可能需要几分钟)...${NC}"
    cd $TEMP_DIR
    # 添加超时和更多参数优化Mythril运行
    timeout 300s myth analyze contracts/$CONTRACT_FILE --solv 0.8.20 -o markdown --execution-timeout 60 --max-depth 10 > $OUTPUT_DIR/mythril-report.md || echo -e "${RED}Mythril分析失败或超时${NC}"
else
    echo -e "${BLUE}跳过 Mythril 分析${NC}"
fi

# 创建简单的 .solhint.json 配置文件
cd $TEMP_DIR
cat > .solhint.json << EOF
{
  "extends": ["solhint:recommended"],
  "rules": {
    "quotes": "off",
    "max-line-length": "off",
    "func-visibility": ["warn", { "ignoreConstructors": true }],
    "compiler-version": ["error", "^0.8.20"],
    "no-empty-blocks": "off",
    "no-inline-assembly": "warn",
    "reason-string": ["warn", { "maxLength": 64 }]
  }
}
EOF

# 运行 Solhint 分析
echo -e "${GREEN}运行 Solhint 分析...${NC}"
cd $TEMP_DIR
/app/node_modules/.bin/solhint contracts/$CONTRACT_FILE > $OUTPUT_DIR/solhint-report.txt || {
    echo -e "${RED}Solhint分析失败${NC}"
    echo "Solhint运行失败，错误代码: $?" > $OUTPUT_DIR/solhint-report.txt
}

# 运行 Surya 分析
echo -e "${GREEN}运行 Surya 分析...${NC}"
cd $TEMP_DIR
# 生成可视化报告
(timeout 30s surya describe contracts/$CONTRACT_FILE > $OUTPUT_DIR/surya-describe.md) || {
    echo -e "${RED}Surya描述生成失败${NC}"
    echo "Surya分析失败，可能不支持某些Solidity 0.8.x特性" > $OUTPUT_DIR/surya-describe.md
}

(timeout 30s surya graph contracts/$CONTRACT_FILE > $OUTPUT_DIR/surya-graph.dot) || {
    echo -e "${RED}Surya图形生成失败${NC}"
}

(timeout 30s surya inheritance contracts/$CONTRACT_FILE > $OUTPUT_DIR/surya-inheritance.dot) || {
    echo -e "${RED}Surya继承图生成失败${NC}"
}

# 生成综合报告
echo -e "${GREEN}生成综合审计报告...${NC}"

cat > $OUTPUT_DIR/comprehensive-audit-report.md << EOF
# 智能合约综合安全审计报告

## 概览
- **合约**: $CONTRACT_FILE
- **合约名称**: $CONTRACT_NAME
- **审计日期**: $(date)
- **使用工具**: Slither, Mythril, Solhint, Surya
- **Solidity版本**: $(solc --version | head -n1)

## 执行结果
- Slither (静态分析): $([ -f "$OUTPUT_DIR/slither-results.json" ] && echo "✅ 完成" || echo "❌ 失败")
- Mythril (符号执行): $([ -f "$OUTPUT_DIR/mythril-report.md" ] && echo "✅ 完成" || echo "❌ 失败")
- Solhint (代码风格): $([ -f "$OUTPUT_DIR/solhint-report.txt" ] && echo "✅ 完成" || echo "❌ 失败")
- Surya (可视化分析): $([ -f "$OUTPUT_DIR/surya-describe.md" ] && echo "✅ 完成" || echo "❌ 失败")

## 详细报告链接

### Slither 静态分析报告
[查看Slither分析报告](./slither-report.md)

### Mythril 符号执行报告
[查看Mythril分析报告](./mythril-report.md)

### Solhint 代码风格报告
[查看Solhint分析报告](./solhint-report.txt)

### Surya 可视化分析报告
[查看Surya描述报告](./surya-describe.md)

## 安全审计结果摘要

$([ -f "$OUTPUT_DIR/slither-results.json" ] && echo "### Slither分析发现的问题：" || echo "")
$([ -f "$OUTPUT_DIR/slither-results.json" ] && grep -o '"description": "[^"]*"' $OUTPUT_DIR/slither-results.json | sed 's/"description": "\(.*\)"/- \1/' || echo "")

$([ -f "$OUTPUT_DIR/solhint-report.txt" ] && echo "### Solhint分析发现的问题：" || echo "")
$([ -f "$OUTPUT_DIR/solhint-report.txt" ] && grep "Error\|Warning" $OUTPUT_DIR/solhint-report.txt | sed 's/^/- /' || echo "")

## 后续步骤
1. 审查所有识别出的问题
2. 按严重性排序修复问题
3. 实施修复
4. 重新运行审计工具验证修复效果
EOF

# 将JSON格式的Slither结果转换为Markdown (如果存在)
if [ -f "$OUTPUT_DIR/slither-results.json" ]; then
    echo "# Slither安全分析报告" > $OUTPUT_DIR/slither-report.md
    echo "" >> $OUTPUT_DIR/slither-report.md
    echo "## 分析结果" >> $OUTPUT_DIR/slither-report.md
    echo '```json' >> $OUTPUT_DIR/slither-report.md
    cat $OUTPUT_DIR/slither-results.json >> $OUTPUT_DIR/slither-report.md
    echo '```' >> $OUTPUT_DIR/slither-report.md
fi

echo -e "${BLUE}安全审计完成！报告保存在 $OUTPUT_DIR 目录${NC}"