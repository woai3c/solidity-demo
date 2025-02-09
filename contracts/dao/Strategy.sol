// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IUniswapV2Router02 } from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { EnumerableSet } from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

contract Strategy is ReentrancyGuard, Pausable, Ownable {
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

  // 状态变量优化 - 使用紧凑存储
  struct PackedStrategy {
    uint128 targetPercentage;
    uint64 rebalanceThreshold;
    uint64 lastUpdateTime; // 新增字段，记录最后更新时间
    address swapPath;
  }

  // 常量定义
  uint256 public constant MAX_SLIPPAGE = 1000; // 10%
  uint256 public constant DEADLINE_GRACE_PERIOD = 20 minutes;
  uint256 public constant MAX_TOKENS = 50; // 限制代币数量
  uint256 public constant MIN_TIMELOCK = 1 days; // 时间锁定期
  uint256 public constant MAX_PRICE_IMPACT = 1000; // 最大价格影响 10%
  bytes32 public immutable DOMAIN_SEPARATOR; // EIP-712 域分隔符

  // 状态变量
  address public immutable vault;
  IUniswapV2Router02 public immutable router;
  uint256 public slippageTolerance = 50; // 0.5%

  mapping(address => bool) public supportedTokens;
  mapping(address => PackedStrategy) public tokenStrategies;
  mapping(bytes32 => uint256) public timeLocks;

  // 事件优化 - 添加索引
  event Invested(address indexed token, uint256 amount, uint256 indexed timestamp);
  event Withdrawn(address indexed token, uint256 amount, uint256 indexed timestamp);
  event RewardsHarvested(uint256 indexed totalValue, uint256 indexed timestamp);
  event StrategyUpdated(address indexed token, uint256 indexed targetPercentage, uint256 indexed rebalanceThreshold);
  event EmergencyWithdraw(address indexed token, address indexed to, uint256 indexed amount);
  event PriceImpactChecked(address indexed tokenIn, address indexed tokenOut, uint256 impact);
  event SwapExecuted(
    address indexed tokenIn,
    address indexed tokenOut,
    uint256 amountIn,
    uint256 amountOut,
    uint256 timestamp
  );

  constructor(address _vault, address _router) ReentrancyGuard() Pausable() Ownable(msg.sender) {
    if (_vault == address(0) || _router == address(0)) revert InvalidToken(address(0));
    vault = _vault;
    router = IUniswapV2Router02(_router);
    DOMAIN_SEPARATOR = keccak256(abi.encode(keccak256('Strategy'), block.chainid, address(this)));
  }

  // 修饰符优化
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
  function invest(address token, uint256 amount) external nonReentrant whenNotPaused onlyVault validToken(token) {
    if (amount == 0) revert InvalidAmount(amount, type(uint256).max);

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
    uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;

    // 获取预期输出金额
    uint256[] memory amounts = router.getAmountsOut(amount, path);
    uint256 minOut = (amounts[1] * (10000 - slippageTolerance)) / 10000;

    // 检查价格影响
    uint256 impact = ((amount - amounts[1]) * 10000) / amount;
    if (impact > MAX_PRICE_IMPACT) {
      revert PriceImpactTooHigh(impact, MAX_PRICE_IMPACT);
    }

    // 授权
    IERC20(tokenIn).forceApprove(address(router), amount);

    // 执行交换
    router.swapExactTokensForTokens(
      amount,
      minOut,
      path,
      address(this),
      block.number + 3 // 使用区块号替代时间戳
    );

    // 验证输出
    uint256 actualOutput = IERC20(tokenOut).balanceOf(address(this)) - balanceBefore;
    if (actualOutput < minOut) {
      revert SwapFailed(tokenIn, tokenOut, amount);
    }

    emit SwapExecuted(tokenIn, tokenOut, amount, actualOutput, block.timestamp);
    return actualOutput;
  }

  // 紧急功能优化
  function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner whenPaused {
    if (to == address(0)) revert InvalidToken(to);
    if (token == address(0)) revert InvalidToken(token);

    uint256 balance = IERC20(token).balanceOf(address(this));
    if (amount > balance) {
      revert InsufficientBalance(token, amount, balance);
    }

    bytes32 operationId = keccak256(abi.encode('EMERGENCY_WITHDRAW', token, to, amount, block.timestamp));

    _setTimelock(operationId);

    IERC20(token).safeTransfer(to, amount);
    emit EmergencyWithdraw(token, to, amount);
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
}
