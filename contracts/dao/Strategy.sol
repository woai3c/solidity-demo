// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IUniswapV2Router02 } from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { EnumerableSet } from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import { Role } from './types.sol';
import { RoleControl } from './utils/RoleControl.sol';

contract Strategy is Ownable, ReentrancyGuard, Pausable, RoleControl {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  // 错误定义优化 - 添加更多信息
  error InvalidToken(address token);
  error InvalidAmount(uint256 provided, uint256 max);
  error InvalidSlippage(uint256 provided, uint256 max);
  error SwapFailed(address tokenIn, address tokenOut, uint256 amount);
  error InsufficientBalance(address token, uint256 requested, uint256 available);
  error DeadlineExpired(uint256 deadline, uint256 current);
  error NotSupported(address token);
  error PriceImpactTooHigh(uint256 impact, uint256 max);
  error OperationNotReady(bytes32 operationId, uint256 unlockTime);
  error ExceedsMaxInvestment();
  error InvalidPercentage(uint256 provided, uint256 max);
  error InvalidThreshold(uint256 provided, uint256 max);
  error InvalidArrayLength();
  error NotAuthorized();

  // 状态变量优化 - 使用紧凑存储
  struct PackedStrategy {
    uint128 targetPercentage;
    uint64 rebalanceThreshold;
    uint64 lastUpdateTime; // 新增字段，记录最后更新时间
    address swapPath;
  }

  // 常量定义
  uint256 public constant MAX_SLIPPAGE = 100; // 1%
  uint256 public constant DEADLINE_GRACE_PERIOD = 20 minutes;
  uint256 public constant MAX_TOKENS = 50; // 限制代币数量
  uint256 public constant MIN_TIMELOCK = 1 days; // 时间锁定期
  uint256 public constant MAX_PRICE_IMPACT = 1000; // 最大价格影响 10%
  uint256 public constant MAX_SINGLE_INVESTMENT = 1000 ether;

  address public vault;
  IUniswapV2Router02 public router;
  uint256 public slippageTolerance;
  bytes32 public DOMAIN_SEPARATOR;
  address public governance;

  mapping(address => bool) public supportedTokens;
  mapping(address => PackedStrategy) public tokenStrategies;
  mapping(bytes32 => uint256) public timeLocks;

  // 事件优化 - 添加索引
  event Invested(address indexed token, uint256 amount, uint256 indexed timestamp);
  event Withdrawn(address indexed token, uint256 amount, uint256 indexed timestamp);
  event RewardsHarvested(uint256 indexed totalValue, uint256 indexed timestamp);
  event StrategyUpdated(address indexed token, uint256 targetPercentage, uint256 rebalanceThreshold, address swapPath);
  event EmergencyWithdraw(address indexed token, uint256 indexed amount, uint256 timestamp);
  event PriceImpactChecked(address indexed tokenIn, address indexed tokenOut, uint256 impact);
  event SwapExecuted(
    address indexed tokenIn,
    address indexed tokenOut,
    uint256 amountIn,
    uint256 amountOut,
    uint256 timestamp
  );

  constructor(address _vault, address _router, address _governance) Ownable(msg.sender) {
    if (_vault == address(0) || _router == address(0) || _governance == address(0)) revert ZeroAddress();
    vault = _vault;
    router = IUniswapV2Router02(_router);
    governance = _governance;

    // 将默认值设置移到此处
    slippageTolerance = 50;

    DOMAIN_SEPARATOR = keccak256(abi.encode(keccak256('Strategy'), block.chainid, address(this)));
  }

  modifier onlyVault() {
    if (msg.sender != vault) revert NotSupported(msg.sender);
    _;
  }

  modifier validToken(address token) {
    if (!supportedTokens[token]) revert NotSupported(token);
    _;
  }

  modifier checkTimelock(bytes32 operationId) {
    uint256 unlockTime = timeLocks[operationId];
    if (block.timestamp < unlockTime) {
      revert OperationNotReady(operationId, unlockTime);
    }
    delete timeLocks[operationId];
    _;
  }

  // 投资功能优化
  function invest(
    address token,
    uint256 amount
  ) external nonReentrant whenNotPaused onlyVault validToken(token) returns (uint256) {
    if (amount == 0) revert InvalidAmount(amount, type(uint256).max);
    if (amount > MAX_SINGLE_INVESTMENT) revert ExceedsMaxInvestment();

    // 缓存余额检查
    uint256 balanceBefore = IERC20(token).balanceOf(address(this));

    // 转账
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    // 验证转账
    if (IERC20(token).balanceOf(address(this)) != balanceBefore + amount) {
      revert InsufficientBalance(token, amount, IERC20(token).balanceOf(address(this)) - balanceBefore);
    }

    _rebalanceIfNeeded(token);

    emit Invested(token, amount, block.timestamp);
    return amount;
  }

  // 提取功能优化
  function withdraw(address token, uint256 amount) external nonReentrant onlyVault validToken(token) {
    if (amount == 0) revert InvalidAmount(amount, type(uint256).max);

    uint256 balance = IERC20(token).balanceOf(address(this));
    if (balance < amount) revert InsufficientBalance(token, amount, balance);

    IERC20(token).safeTransfer(msg.sender, amount);

    emit Withdrawn(token, amount, block.timestamp);
  }

  // 收益收割优化
  function harvest() external nonReentrant whenNotPaused onlyVault {
    address[] memory tokens = _getSupportedTokens();
    uint256 length = tokens.length;
    uint256 totalValue;

    for (uint256 i; i < length; ) {
      address token = tokens[i];
      PackedStrategy memory strategy = tokenStrategies[token];

      if (strategy.targetPercentage > 0) {
        _rebalanceIfNeeded(token);
      }

      totalValue += _getTokenValue(token);

      unchecked {
        ++i;
      }
    }

    emit RewardsHarvested(totalValue, block.timestamp);
  }

  // 代币操作优化
  function _swapTokens(address tokenIn, address tokenOut, uint256 amount) internal returns (uint256 amountOut) {
    // 检查-效果-交互模式
    // 1. 记录交换前的余额，用于后续验证
    uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

    // 2. 构建交易路径
    address[] memory path = new address[](2);
    path[0] = tokenIn; // 输入代币
    path[1] = tokenOut; // 输出代币

    // 3. 获取预期输出金额
    uint256[] memory amounts = router.getAmountsOut(amount, path);
    // amounts[0] 是输入金额
    // amounts[1] 是预期输出金额

    // 4. 计算最小接收量（考虑滑点）
    // 例如：slippageTolerance = 50 表示 0.5% 的滑点
    // 如果预期输出 100 个代币，那么最少接收 99.5 个
    uint256 minOut = (amounts[1] * (10000 - slippageTolerance)) / 10000;

    // 5. 检查价格影响
    uint256 impact = ((amount - amounts[1]) * 10000) / amount;
    if (impact > MAX_PRICE_IMPACT) {
      revert PriceImpactTooHigh(impact, MAX_PRICE_IMPACT);
    }

    // 6. 授权 Router 使用代币
    IERC20(tokenIn).forceApprove(address(router), amount);

    // 7. 执行交换
    router.swapExactTokensForTokens(
      amount, // 输入数量
      minOut, // 最小接收数量
      path, // 交易路径
      address(this), // 接收地址
      block.number + 3 // 截止区块
    );

    // 8. 验证输出
    uint256 actualOutput = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
    if (actualOutput < minOut) {
      revert SwapFailed(tokenIn, tokenOut, amount);
    }

    // 9. 记录事件
    emit SwapExecuted(tokenIn, tokenOut, amount, actualOutput, block.timestamp);
    return actualOutput;
  }

  function emergencyWithdraw(address token) external onlyOwner whenPaused {
    if (token == address(0)) revert InvalidToken(token);

    uint256 balance = IERC20(token).balanceOf(address(this));
    if (balance == 0) {
      revert InsufficientBalance(token, balance, balance);
    }

    IERC20(token).safeTransfer(vault, balance);

    // 更新事件发送，添加时间戳
    emit EmergencyWithdraw(token, balance, block.timestamp);
  }

  // 内部辅助函数
  function _validateBalance(address token, uint256 expectedBalance) internal view {
    uint256 actualBalance = IERC20(token).balanceOf(address(this));
    if (actualBalance < expectedBalance) {
      revert InsufficientBalance(token, expectedBalance, actualBalance);
    }
  }

  function _setTimelock(bytes32 operationId) internal {
    timeLocks[operationId] = block.timestamp + MIN_TIMELOCK;
  }

  function _calculatePercentage(uint256 part, uint256 total) internal pure returns (uint256) {
    if (total == 0) return 0;
    return (part * 10000) / total;
  }

  // 获取代币价值
  function _getTokenValue(address token) internal view returns (uint256) {
    if (!supportedTokens[token]) return 0;
    return IERC20(token).balanceOf(address(this));
  }

  // 估算总收益
  function estimateReturns() external view returns (uint256 totalValue) {
    address[] memory tokens = _getSupportedTokens();
    uint256 length = tokens.length;

    for (uint256 i; i < length; ) {
      totalValue += _getTokenValue(tokens[i]);
      unchecked {
        ++i;
      }
    }
  }

  // 获取支持的代币列表
  EnumerableSet.AddressSet private _supportedTokensSet;

  function _getSupportedTokens() internal view returns (address[] memory) {
    uint256 length = _supportedTokensSet.length();
    address[] memory tokens = new address[](length);

    for (uint256 i = 0; i < length; ) {
      tokens[i] = _supportedTokensSet.at(i);
      unchecked {
        ++i;
      }
    }

    return tokens;
  }

  // View functions optimization
  function getStrategySummary(
    address token
  ) external view returns (uint256 currentValue, uint256 targetValue, uint256 percentage, uint256 deviation) {
    PackedStrategy memory strategy = tokenStrategies[token];
    currentValue = _getTokenValue(token);
    uint256 totalValue = this.estimateReturns();

    percentage = _calculatePercentage(currentValue, totalValue);
    targetValue = (totalValue * strategy.targetPercentage) / 10000;

    deviation = percentage > strategy.targetPercentage
      ? percentage - strategy.targetPercentage
      : strategy.targetPercentage - percentage;
  }

  function _rebalanceIfNeeded(address token) internal {
    PackedStrategy memory strategy = tokenStrategies[token];
    if (strategy.targetPercentage == 0) return;

    uint256 currentPercentage = _getTokenPercentage(token);
    uint256 diff = currentPercentage > strategy.targetPercentage
      ? currentPercentage - strategy.targetPercentage
      : strategy.targetPercentage - currentPercentage;

    if (diff > strategy.rebalanceThreshold) {
      _rebalanceToken(token, strategy);
    }
  }

  function _rebalanceToken(address token, PackedStrategy memory strategy) internal {
    uint256 currentPercentage = _getTokenPercentage(token);

    if (currentPercentage > strategy.targetPercentage) {
      // Need to sell tokens
      uint256 excess = (IERC20(token).balanceOf(address(this)) * (currentPercentage - strategy.targetPercentage)) /
        currentPercentage;

      _swapTokens(token, strategy.swapPath, excess);
    } else {
      // Need to buy tokens
      uint256 required = (IERC20(strategy.swapPath).balanceOf(address(this)) *
        (strategy.targetPercentage - currentPercentage)) / (10000 - currentPercentage);

      _swapTokens(strategy.swapPath, token, required);
    }
  }

  function _getTokenPercentage(address token) internal view returns (uint256) {
    uint256 totalValue = this.estimateReturns();
    if (totalValue == 0) return 0;

    return _calculatePercentage(_getTokenValue(token), totalValue);
  }

  // 内部函数：处理单个策略更新的核心逻辑
  function _updateSingleStrategy(
    address token,
    uint256 targetPercentage,
    uint256 rebalanceThreshold,
    address swapPath
  ) internal {
    // 验证参数
    if (targetPercentage > 10000) {
      revert InvalidPercentage(targetPercentage, 10000);
    }
    if (rebalanceThreshold > 10000) {
      revert InvalidThreshold(rebalanceThreshold, 10000);
    }
    if (!supportedTokens[token]) {
      revert NotSupported(token);
    }

    // 更新策略
    tokenStrategies[token] = PackedStrategy({
      targetPercentage: uint128(targetPercentage),
      rebalanceThreshold: uint64(rebalanceThreshold),
      lastUpdateTime: uint64(block.timestamp),
      swapPath: swapPath
    });

    // 触发事件
    emit StrategyUpdated(token, targetPercentage, rebalanceThreshold, swapPath);

    // 如果需要，执行再平衡
    _rebalanceIfNeeded(token);
  }

  // 修改权限控制，只允许 Governance 调用
  function updateStrategy(
    address token,
    uint256 targetPercentage,
    uint256 rebalanceThreshold,
    address swapPath
  ) external onlyGovernance whenNotPaused {
    _updateSingleStrategy(token, targetPercentage, rebalanceThreshold, swapPath);
  }

  // 批量更新策略
  function updateStrategies(
    address[] calldata tokens,
    uint256[] calldata targetPercentages,
    uint256[] calldata rebalanceThresholds,
    address[] calldata swapPaths
  ) external onlyGovernance whenNotPaused {
    // 检查数组长度
    if (
      tokens.length != targetPercentages.length ||
      tokens.length != rebalanceThresholds.length ||
      tokens.length != swapPaths.length
    ) {
      revert InvalidArrayLength();
    }

    // 检查总百分比不超过 100%
    uint256 totalPercentage;
    for (uint256 i = 0; i < targetPercentages.length; i++) {
      totalPercentage += targetPercentages[i];
    }
    if (totalPercentage > 10000) {
      revert InvalidPercentage(totalPercentage, 10000);
    }

    // 批量更新
    for (uint256 i = 0; i < tokens.length; i++) {
      _updateSingleStrategy(tokens[i], targetPercentages[i], rebalanceThresholds[i], swapPaths[i]);
    }
  }

  // 查看当前策略
  function getStrategy(
    address token
  )
    external
    view
    returns (uint256 targetPercentage, uint256 rebalanceThreshold, uint256 lastUpdateTime, address swapPath)
  {
    PackedStrategy memory strategy = tokenStrategies[token];
    return (strategy.targetPercentage, strategy.rebalanceThreshold, strategy.lastUpdateTime, strategy.swapPath);
  }

  // 添加 onlyGovernance 修饰器
  modifier onlyGovernance() {
    if (msg.sender != governance) revert NotAuthorized();
    _;
  }

  // 添加更新 governance 地址的函数
  function setGovernance(address _governance) external onlyOwner {
    require(_governance != address(0), 'Zero address');
    governance = _governance;
  }
}
