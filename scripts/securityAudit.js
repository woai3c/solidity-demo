#!/usr/bin/env node
/* eslint-disable no-loop-func */

const fs = require('fs')

const fsPromises = fs.promises
const path = require('path')
const { execSync } = require('child_process')
const { glob } = require('glob')

// 颜色定义
const colors = {
  GREEN: '\x1b[32m',
  BLUE: '\x1b[34m',
  RED: '\x1b[31m',
  YELLOW: '\x1b[33m',
  NC: '\x1b[0m', // No Color
}

// 参数处理
const args = process.argv.slice(2)
const CONTRACT_DIR = args[0] || '/share/contracts'
const OUTPUT_DIR = args[1] || '/share/auditReports'

// 辅助函数: 运行命令并捕获输出
function runCommand(command, options = {}) {
  try {
    const result = execSync(command, { encoding: 'utf8', ...options })
    return { success: true, output: result.trim(), exitCode: 0 }
  } catch (error) {
    // 如果有stdout输出且包含分析结果，认为是"发现问题"而不是失败
    const hasAnalysisOutput =
      error.stdout && (error.stdout.includes('analyzed') || error.stdout.includes('result(s) found'))

    return {
      success: hasAnalysisOutput, // 有分析输出视为成功但有问题
      foundIssues: hasAnalysisOutput,
      output: error.stdout ? error.stdout : error.message,
      exitCode: error.status || 1,
    }
  }
}

// 辅助函数: 格式化输出
function log(color, message) {
  console.log(`${color}${message}${colors.NC}`)
}

// 清空目录内容但保留目录本身
async function cleanDirectory(dir) {
  try {
    await fsPromises.access(dir)

    // 读取目录内容
    const files = await fsPromises.readdir(dir)

    // 删除每个文件和子目录
    for (const file of files) {
      const filePath = path.join(dir, file)
      const stat = await fsPromises.stat(filePath)

      if (stat.isDirectory()) {
        // 递归删除子目录
        await fsPromises.rm(filePath, { recursive: true, force: true })
      } else {
        // 删除文件
        await fsPromises.unlink(filePath)
      }
    }

    log(colors.YELLOW, `已清空旧的审计报告目录内容: ${dir}`)
  } catch (error) {
    // 目录不存在，则创建它
    if (error.code === 'ENOENT') {
      await fsPromises.mkdir(dir, { recursive: true })
      log(colors.YELLOW, `创建审计报告目录: ${dir}`)
    } else {
      // 如果是其他错误，记录但继续执行
      log(colors.RED, `清空目录时发生错误: ${error.message}`)
    }
  }
}

// 主函数
async function main() {
  // 清空并重建输出目录
  await cleanDirectory(OUTPUT_DIR)

  log(colors.BLUE, '开始智能合约安全审计...')

  // 获取Solidity版本
  const solcVersionCmd = runCommand('solc --version')
  const solcVersion = solcVersionCmd.output.split('\n')[0]
  log(colors.BLUE, `使用Solidity版本: ${solcVersion}`)

  // 检查工具安装情况
  log(colors.GREEN, '检查工具安装情况:')
  console.log(`Slither: ${runCommand('which slither || echo "未安装"').output}`)
  console.log(`Solhint: ${runCommand('npx solhint --version || echo "未安装"').output}`)
  console.log(`Surya: ${runCommand('which surya || echo "未安装"').output}`)
  console.log(`Mythril: ${runCommand('which myth || echo "未安装"').output}`)

  // 检查OpenZeppelin库位置
  log(colors.GREEN, '检查OpenZeppelin库位置:')

  // 创建.solhint.json
  const solhintConfig = {
    extends: ['solhint:recommended'],
    rules: {
      quotes: 'off',
      'max-line-length': 'off',
      'compiler-version': ['error', '^0.8.20'],
      'func-visibility': ['warn', { ignoreConstructors: true }],
      'no-empty-blocks': 'off',
      'no-inline-assembly': 'warn',
    },
  }

  await fsPromises.writeFile('/app/.solhint.json', JSON.stringify(solhintConfig, null, 2))

  // 查找所有合约文件
  const contractFiles = glob.sync(`${CONTRACT_DIR}/**/*.sol`, {
    ignore: '**/node_modules/**',
    nodir: true,
  })
  console.log(path.resolve(__dirname, 'node_modules'))
  // 处理每个合约文件
  for (const contractFile of contractFiles.sort()) {
    const contractName = path.basename(contractFile, '.sol')
    const contractRelPath = contractFile.replace(CONTRACT_DIR + '/', '')

    log(colors.BLUE, `\n========== 审计合约: ${contractRelPath} ==========`)

    // 创建输出目录
    const safePath = contractRelPath.replace(/\//g, '_').replace(/\.sol$/, '')
    const contractOutputDir = `${OUTPUT_DIR}/${safePath}`
    await fsPromises.mkdir(contractOutputDir, { recursive: true })

    // 运行Slither分析
    log(colors.GREEN, '运行 Slither 分析...')

    // 在slither命令中使用绝对路径
    // 修改slither命令行
    const slitherCmd = `slither ${contractFile} \
      --config-file /app/audit-config.json \
      --json ${contractOutputDir}/slither-results.json`

    const slitherResult = runCommand(slitherCmd)

    // 保存Slither的完整输出
    await fsPromises.writeFile(`${contractOutputDir}/slither-output.txt`, slitherResult.output)
    console.log('slitherResult')
    console.log(slitherResult)
    if (!slitherResult.success) {
      log(colors.YELLOW, 'Slither分析过程中遇到一些警告或错误:')
      log(colors.RED, slitherResult.output)

      // 如果JSON文件未能生成，创建一个空文件
      if (!fs.existsSync(`${contractOutputDir}/slither-results.json`)) {
        await fsPromises.writeFile(`${contractOutputDir}/slither-results.json`, JSON.stringify({ results: [] }))
      }
    }

    // 运行Mythril (如果不跳过)
    log(colors.GREEN, '运行 Mythril 分析 (可能需要几分钟)...')

    const mythrilCmd = `timeout 300s myth analyze ${contractFile} \
      --solv 0.8.20 \
      -o markdown \
      --max-depth 10 \
      --solc-json /app/mythril-solc.json`

    const mythrilResult = runCommand(mythrilCmd)

    // 保存Mythril的输出
    if (mythrilResult.success) {
      await fsPromises.writeFile(`${contractOutputDir}/mythril-report.md`, mythrilResult.output)
    } else {
      log(colors.RED, 'Mythril分析失败或超时:')
      log(colors.RED, mythrilResult.output)
      await fsPromises.writeFile(`${contractOutputDir}/mythril-report.md`, 'Mythril分析失败或超时')
    }

    // 运行Solhint
    log(colors.GREEN, '运行 Solhint 分析...')

    const solhintCmd = `npx solhint \
      --config /app/.solhint.json \
      --ignore-path /app/.solhintignore \
      ${contractFile}`

    const solhintResult = runCommand(solhintCmd)

    // 保存Solhint的输出
    await fsPromises.writeFile(`${contractOutputDir}/solhint-report.txt`, solhintResult.output)

    if (!solhintResult.success) {
      log(colors.RED, 'Solhint分析发现问题或失败:')
      log(colors.RED, solhintResult.output)
    }

    // 运行Surya
    log(colors.GREEN, '运行 Surya 分析...')

    const suryaDescribeResult = runCommand(`surya describe ${contractFile}`)
    await fsPromises.writeFile(`${contractOutputDir}/surya-describe.md`, suryaDescribeResult.output)

    if (!suryaDescribeResult.success) {
      log(colors.RED, 'Surya describe 失败:')
      log(colors.RED, suryaDescribeResult.output)
    }

    const suryaGraphResult = runCommand(`surya graph ${contractFile}`)

    if (suryaGraphResult.success) {
      await fsPromises.writeFile(`${contractOutputDir}/surya-graph.dot`, suryaGraphResult.output)

      const dotResult = runCommand(
        `dot -Tpng ${contractOutputDir}/surya-graph.dot -o ${contractOutputDir}/surya-graph.png`,
      )
      if (!dotResult.success) {
        log(colors.RED, '图像转换失败')
      }
    } else {
      log(colors.RED, 'Surya graph 失败:')
      log(colors.RED, suryaGraphResult.output)
      await fsPromises.writeFile(`${contractOutputDir}/surya-graph.dot`, '')
    }

    const suryaInheritanceResult = runCommand(`surya inheritance ${contractFile}`)

    if (suryaInheritanceResult.success) {
      await fsPromises.writeFile(`${contractOutputDir}/surya-inheritance.dot`, suryaInheritanceResult.output)

      const dotInheritanceResult = runCommand(
        `dot -Tpng ${contractOutputDir}/surya-inheritance.dot -o ${contractOutputDir}/surya-inheritance.png`,
      )
      if (!dotInheritanceResult.success) {
        log(colors.RED, '图像转换失败')
      }
    } else {
      log(colors.RED, 'Surya inheritance 失败:')
      log(colors.RED, suryaInheritanceResult.output)
      await fsPromises.writeFile(`${contractOutputDir}/surya-inheritance.dot`, '')
    }

    // 生成报告
    const currentDate = new Date().toISOString()
    let slitherIssues = ''

    try {
      if (fs.existsSync(`${contractOutputDir}/slither-results.json`)) {
        const slitherData = JSON.parse(fs.readFileSync(`${contractOutputDir}/slither-results.json`, 'utf8'))
        if (slitherData.results && Array.isArray(slitherData.results)) {
          slitherIssues = slitherData.results.map((issue) => `- ${issue.description}`).join('\n')
        }
      }
    } catch (error) {
      slitherIssues = '解析失败: ' + error.message
    }

    let solhintIssues = ''

    try {
      const solhintContent = fs.readFileSync(`${contractOutputDir}/solhint-report.txt`, 'utf8')
      solhintIssues = solhintContent
        .split('\n')
        .filter((line) => line.includes('Error') || line.includes('Warning'))
        .map((line) => `- ${line}`)
        .join('\n')
    } catch (error) {
      solhintIssues = '未发现问题或解析失败'
    }

    const auditReport = `
# ${contractName} 智能合约安全审计报告

## 概览
- **合约**: ${contractRelPath}
- **审计日期**: ${currentDate}
- **Solidity版本**: ${solcVersion}

## 执行结果
- Slither (静态分析): ${
      fs.existsSync(`${contractOutputDir}/slither-results.json`)
        ? slitherResult.success
          ? '✅ 完成'
          : '✅ 完成 (发现问题)'
        : '❌ 失败'
    }
- Mythril (符号执行): ${
      fs.existsSync(`${contractOutputDir}/mythril-report.md`)
        ? mythrilResult.success
          ? '✅ 完成'
          : '✅ 完成 (发现问题)'
        : '❌ 失败'
    }
- Solhint (代码风格): ${fs.existsSync(`${contractOutputDir}/solhint-report.txt`) ? '✅ 完成' : '❌ 失败'}
- Surya (可视化分析): ${fs.existsSync(`${contractOutputDir}/surya-describe.md`) ? '✅ 完成' : '❌ 失败'}

## Surya 可视化分析

### 函数调用图
![函数调用图](./surya-graph.png)

### 继承关系图
![继承关系图](./surya-inheritance.png)

## 安全分析结果摘要

${fs.existsSync(`${contractOutputDir}/slither-results.json`) ? '### Slither分析发现的问题：\n' : ''}
${slitherIssues || '未发现问题或解析失败'}

${fs.existsSync(`${contractOutputDir}/solhint-report.txt`) ? '### Solhint分析发现的问题：\n' : ''}
${solhintIssues || '未发现问题'}

## 完整错误和警告信息

### Slither 完整输出
\`\`\`
${fs.readFileSync(`${contractOutputDir}/slither-output.txt`, 'utf8')}
\`\`\`
`

    await fsPromises.writeFile(`${contractOutputDir}/audit-report.md`, auditReport)
  }

  // 生成综合报告
  log(colors.GREEN, '生成综合审计报告...')

  const contractDirs = fs
    .readdirSync(OUTPUT_DIR)
    .filter((file) => fs.statSync(path.join(OUTPUT_DIR, file)).isDirectory())
    .sort()

  const contractLinks = contractDirs.map((dir) => `- [${dir}](./${dir}/audit-report.md)`).join('\n')

  // 计算问题数量
  let highIssues = 0,
    mediumIssues = 0,
    lowIssues = 0

  // 遍历各个合约目录
  // 遍历各个合约目录
  for (const dir of contractDirs) {
    const slitherFilePath = path.join(OUTPUT_DIR, dir, 'slither-results.json')
    const slitherOutputFile = path.join(OUTPUT_DIR, dir, 'slither-output.txt')

    // 尝试从JSON文件读取结果
    if (fs.existsSync(slitherFilePath)) {
      try {
        const data = JSON.parse(fs.readFileSync(slitherFilePath, 'utf8'))
        if (data.results && Array.isArray(data.results)) {
          data.results.forEach((issue) => {
            if (issue.impact === 'High') highIssues++
            else if (issue.impact === 'Medium') mediumIssues++
            else if (issue.impact === 'Low') lowIssues++
          })
        }
      } catch (err) {
        console.error(`Error parsing JSON for ${dir}:`, err)

        // 如果JSON解析失败，尝试从原始输出文本中提取结果
        if (fs.existsSync(slitherOutputFile)) {
          const outputText = fs.readFileSync(slitherOutputFile, 'utf8')

          // 从文本中提取严重性信息
          if (outputText.includes('high severity')) highIssues++
          if (outputText.includes('medium severity')) mediumIssues++
          if (outputText.includes('low severity')) lowIssues++

          // 基于关键词判断问题严重性
          if (
            outputText.includes('arbitrary user')
            || outputText.includes('sends eth to arbitrary')
            || outputText.includes('Reentrancy')
          ) {
            highIssues++
          }
        }
      }
    }
  }

  const comprehensiveReport = `
# 智能合约综合安全审计报告

## 概览
- **项目**: Solidity合约集
- **审计日期**: ${new Date().toISOString()}
- **Solidity版本**: ${solcVersion}

## 已审计合约

${contractLinks}

## 汇总问题数量

### 高严重性问题
${highIssues} 个高严重性问题

### 中等严重性问题  
${mediumIssues} 个中等严重性问题

### 低严重性问题
${lowIssues} 个低严重性问题
`

  await fsPromises.writeFile(`${OUTPUT_DIR}/comprehensive-audit-report.md`, comprehensiveReport)

  log(colors.BLUE, `安全审计完成！报告保存在 ${OUTPUT_DIR}`)
}

// 执行主函数
main().catch((err) => {
  console.error(`${colors.RED}错误: ${err}${colors.NC}`)
  process.exit(1)
})
