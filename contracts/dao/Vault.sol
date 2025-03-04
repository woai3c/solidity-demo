// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { IERC20Metadata } from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import { EnumerableSet } from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { IPriceFeed } from './types.sol';
import { ChainlinkPriceFeed } from './utils/ChainlinkPriceFeed.sol';
import { IAccessControl } from './types.sol';
import { Role } from './types.sol';
import { RoleControl } from './utils/RoleControl.sol';

contract Vault is ERC20, ReentrancyGuard, Pausable, Ownable, RoleControl {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  // 自定义错误
  error InvalidPriceFeed();
  error InvalidToken();
  error TokenAlreadySupported();
  error TokenNotSupported();
  error DepositTooLow();
  error DepositTooHigh();
  error InsufficientShares();
  error TransferFailed();
  error InvalidAmount();
  error MaxTokensReached();
  error NotAuthorized();
  error InvalidPrice();
  error OperationFailed();
  error InvalidAccessControl();
  error InvalidGovernance();
  error InvalidStrategy();
  error InvalidInput();

  // 价格预言机
  IPriceFeed public priceFeed;

  // 最小存款金额
  uint256 public minimumDeposit;
  // 最大存款金额
  uint256 public maxDeposit;
  // 最小代币存款金额
  uint256 public minimunTokenDeposit;

  // 支持的代币集合
  EnumerableSet.AddressSet private supportedTokensSet;
  // 代币精度
  mapping(address => uint8) public tokenDecimals;

  // 总资产价值 (以USD计价)
  uint256 public totalAssets;

  // 费用结构
  struct Fee {
    uint256 depositFee; // 存款费用（基点：1/10000）
    uint256 withdrawFee; // 提款费用
    uint256 managementFee; // 管理费
  }

  Fee public fees;

  // 收益分配
  uint256 public totalProfits;
  mapping(address => uint256) public userProfits;

  // 用户信息
  struct UserInfo {
    uint256 depositCount;
    uint256 totalDeposited;
    uint256 lastDepositTime;
    bool isWhitelisted;
  }

  mapping(address => UserInfo) public userInfo;

  // 存款事件
  event Deposit(address indexed user, uint256 amount, uint256 shares);
  // 提款事件
  event Withdraw(address indexed user, uint256 amount, uint256 shares);
  // 紧急提款事件
  event EmergencyWithdraw(address indexed user, uint256 amount);
  // 代币紧急提款事件
  event EmergencyWithdrawToken(address indexed user, address indexed token, uint256 amount);
  // 添加支持代币事件
  event TokenAdded(address indexed token);
  // 移除支持代币事件
  event TokenRemoved(address indexed token);
  // 收益分配事件
  event ProfitDistributed(uint256 amount);
  // 费用更新事件
  event FeeUpdated(uint256 depositFee, uint256 withdrawFee, uint256 managementFee);
  // 收益存入事件
  event ProfitDeposited(uint256 amount);
  event TokenProfitDeposited(address indexed token, uint256 amount);
  event AccessControlSet(address indexed accessControl);
  event GovernanceSet(address indexed oldGovernance, address indexed newGovernance);
  event StrategySet(address indexed oldStrategy, address indexed newStrategy);

  // 收益分配相关状态变量
  struct RewardInfo {
    uint256 rewardPerShare; // 每份额累计收益（精度为1e12）
    uint256 totalRewards; // 总收益
    uint256 lastUpdateTime; // 最后更新时间
  }

  struct UserRewardInfo {
    uint256 rewardDebt; // 用户已结算的收益债务
    uint256 pending; // 待领取的收益
    uint256 lastRewardPerShare; // 用户最后结算时的每股收益
  }

  RewardInfo public rewardInfo;
  mapping(address => UserRewardInfo) public userRewardInfo;

  // 更新收益事件
  event RewardUpdated(uint256 newRewards, uint256 rewardPerShare);
  // 收益认领事件
  event RewardClaimed(address indexed user, uint256 amount);

  // 优化存储布局
  struct PackedVaultData {
    uint64 lastUpdateTime;
    uint64 cooldownPeriod;
    uint128 totalAssets;
  }
  PackedVaultData internal vaultData;

  // 添加详细事件
  event FeesUpdated(uint256 indexed oldDepositFee, uint256 indexed newDepositFee, uint256 indexed timestamp);

  // 添加 AccessControl 接口
  IAccessControl public accessControl;

  // 添加状态变量
  address public governance;
  address public strategy;

  constructor(
    string memory name,
    string memory symbol,
    address[] memory supportedTokens,
    address _accessControl
  ) ERC20(name, symbol) Ownable(msg.sender) {
    if (_accessControl == address(0)) revert ZeroAddress();
    accessControl = IAccessControl(_accessControl);

    // Initialize state variables
    minimumDeposit = 0.1 ether;
    maxDeposit = 100 ether;
    minimunTokenDeposit = 100 * 1e6; // 100 USDC

    // Initialize fee structure
    fees = Fee({
      depositFee: 50, // 0.5%
      withdrawFee: 50, // 0.5%
      managementFee: 200 // 2%
    });

    // Add initial supported tokens
    for (uint256 i = 0; i < supportedTokens.length; ) {
      if (supportedTokens[i] != address(0)) {
        _addToken(supportedTokens[i]);
      }
      unchecked {
        ++i;
      }
    }
  }

  // Helper function to add token
  function _addToken(address token) private {
    if (!_isContract(token)) revert InvalidToken();
    supportedTokensSet.add(token);
    tokenDecimals[token] = IERC20Metadata(token).decimals();
    emit TokenAdded(token);
  }

  // =========================
  // 存款函数
  // =========================

  // 存入ETH
  function deposit() external payable nonReentrant whenNotPaused checkLimit(msg.value) {
    if (msg.value < minimumDeposit) revert DepositTooLow();
    if (msg.value > maxDeposit) revert DepositTooHigh();

    uint256 fee = (msg.value * fees.depositFee) / 10000;
    uint256 amountAfterFee = msg.value - fee;

    // 更新用户信息
    UserInfo storage user = userInfo[msg.sender];
    user.depositCount++;
    user.totalDeposited += amountAfterFee;
    user.lastDepositTime = block.timestamp;

    uint256 usdValue = calculateUSDValue(address(0), amountAfterFee);
    uint256 shares = calculateShares(usdValue);

    _mint(msg.sender, shares);
    totalAssets += usdValue;

    emit Deposit(msg.sender, amountAfterFee, shares);

    _updateUserReward(msg.sender);
  }

  // 存入ERC20代币
  function depositToken(address token, uint256 amount) external nonReentrant whenNotPaused checkLimit(amount) {
    if (!isSupportedToken(token)) revert TokenNotSupported();
    if (amount < minimunTokenDeposit) revert DepositTooLow();
    if (amount > maxDeposit) revert DepositTooHigh();

    uint256 fee = (amount * fees.depositFee) / 10000;
    uint256 amountAfterFee = amount - fee;

    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    uint256 usdValue = calculateUSDValue(token, amountAfterFee);
    uint256 shares = calculateShares(usdValue);

    _mint(msg.sender, shares);
    totalAssets += usdValue;

    emit Deposit(msg.sender, amountAfterFee, shares);

    _updateUserReward(msg.sender);
  }

  // =========================
  // 提款函数
  // =========================

  // 提取ETH
  function withdraw(uint256 shareAmount) external nonReentrant whenNotPaused {
    if (shareAmount == 0) revert InvalidAmount();
    if (shareAmount > balanceOf(msg.sender)) revert InsufficientShares();

    uint256 assets = calculateAssets(shareAmount);
    uint256 fee = (assets * fees.withdrawFee) / 10000;
    uint256 amountAfterFee = assets - fee;

    _burn(msg.sender, shareAmount);
    totalAssets -= assets;

    (bool success, ) = payable(msg.sender).call{ value: amountAfterFee }('');
    if (!success) revert TransferFailed();

    emit Withdraw(msg.sender, amountAfterFee, shareAmount);

    _updateUserReward(msg.sender);
  }

  // 提取ERC20代币
  function withdrawToken(address token, uint256 shareAmount) external nonReentrant whenNotPaused {
    if (!isSupportedToken(token)) revert TokenNotSupported();
    if (shareAmount == 0) revert InvalidAmount();
    if (shareAmount > balanceOf(msg.sender)) revert InsufficientShares();

    uint256 assets = calculateAssets(shareAmount);
    uint256 fee = (assets * fees.withdrawFee) / 10000;
    uint256 amountAfterFee = assets - fee;

    _burn(msg.sender, shareAmount);
    totalAssets -= assets;

    uint256 tokenAmount = (amountAfterFee * (10 ** tokenDecimals[token])) / getValidPrice(token);
    IERC20(token).safeTransfer(msg.sender, tokenAmount);

    emit Withdraw(msg.sender, amountAfterFee, shareAmount);

    _updateUserReward(msg.sender);
  }

  // =========================
  // 计算函数
  // =========================

  // 从预言机获取价格
  function getValidPrice(address token) internal view returns (uint256) {
    uint256 price = priceFeed.getPrice(token);
    if (price == 0) revert InvalidPrice();
    return price;
  }

  // 计算 USD 价值
  function calculateUSDValue(address token, uint256 amount) public view returns (uint256) {
    uint256 tokenPrice = getValidPrice(token);
    if (token == address(0)) {
      // ETH: amount(wei) * price / 1e18 = USD value
      return (amount * tokenPrice) / 1e18;
    } else {
      // ERC20: amount * price / (10 ** decimals) = USD value
      return (amount * tokenPrice) / (10 ** tokenDecimals[token]);
    }
  }

  // 份额计算精度
  uint256 private constant PRECISION = 1e18;

  // 计算应得份额
  function calculateShares(uint256 usdValue) public view returns (uint256) {
    // 首次存款
    if (totalSupply() == 0 || totalAssets == 0) {
      return usdValue * PRECISION;
    }

    // 根据存入价值和当前资产比例计算份额
    return (usdValue * totalSupply()) / totalAssets;
  }

  // 计算份额对应的资产数量
  function calculateAssets(uint256 shareAmount) public view returns (uint256) {
    if (totalSupply() == 0) {
      return 0;
    }

    // 根据份额占比计算对应资产
    return (shareAmount * totalAssets) / totalSupply();
  }

  // =========================
  // 代币管理函数
  // =========================

  // 添加支持的代币
  function addSupportedToken(address token) external onlyRole(Role.ADMIN) {
    if (token == address(0)) revert InvalidToken();
    if (isSupportedToken(token)) revert TokenAlreadySupported();
    if (supportedTokensSet.length() >= 50) revert MaxTokensReached();
    if (!_isContract(token)) revert InvalidToken();

    supportedTokensSet.add(token);
    tokenDecimals[token] = IERC20Metadata(token).decimals();

    emit TokenAdded(token);
  }

  // 移除支持的代币
  function removeSupportedToken(address token) external onlyRole(Role.ADMIN) {
    if (!isSupportedToken(token)) revert TokenNotSupported();

    supportedTokensSet.remove(token);
    delete tokenDecimals[token];

    emit TokenRemoved(token);
  }

  // 检查代币是否支持
  function isSupportedToken(address token) public view returns (bool) {
    return supportedTokensSet.contains(token);
  }

  // 获取支持的代币列表
  function getSupportedTokens() external view returns (address[] memory) {
    return supportedTokensSet.values();
  }

  // =========================
  // 参数设置函数
  // =========================

  // 设置最小存款额
  function setMinimumDeposit(uint256 _minimumDeposit) external onlyRole(Role.ADMIN) {
    minimumDeposit = _minimumDeposit;
  }

  // 设置最大存款额
  function setMaxDeposit(uint256 _maxDeposit) external onlyRole(Role.ADMIN) {
    maxDeposit = _maxDeposit;
  }

  // 设置费用
  function setFees(uint256 _depositFee, uint256 _withdrawFee, uint256 _managementFee) external onlyRole(Role.ADMIN) {
    if (_depositFee > 1000) revert InvalidAmount(); // 最大10%
    if (_withdrawFee > 1000) revert InvalidAmount();
    if (_managementFee > 500) revert InvalidAmount(); // 最大5%

    uint256 oldDepositFee = fees.depositFee;
    fees = Fee(_depositFee, _withdrawFee, _managementFee);
    emit FeeUpdated(_depositFee, _withdrawFee, _managementFee);
    emit FeesUpdated(oldDepositFee, _depositFee, block.timestamp);
  }

  // 分配收益
  function distributeProfit() external onlyRole(Role.SUPER_ADMIN) {
    uint256 currentBalance = totalAssets;
    uint256 profit = currentBalance - totalSupply();
    if (profit <= 0) revert InvalidAmount();

    // 使用更高效的方式：更新全局收益变量
    rewardInfo.totalRewards += profit;

    // 计算新的每股收益（精度1e12）
    uint256 newRewardPerShare = (profit * 1e12) / totalSupply();
    rewardInfo.rewardPerShare += newRewardPerShare;
    rewardInfo.lastUpdateTime = block.timestamp;

    totalProfits += profit;

    emit ProfitDistributed(profit);
    emit RewardUpdated(profit, rewardInfo.rewardPerShare);
  }

  // =========================
  // 合约控制函数
  // =========================

  // 暂停合约
  function pause() external onlyOwner whenNotPaused {
    _pause();
  }

  // 恢复合约
  function unpause() external onlyOwner whenPaused {
    _unpause();
  }

  // 紧急提款（管理员功能）
  function emergencyWithdraw() external onlyRole(Role.SUPER_ADMIN) {
    // 提取ETH
    uint256 ethBalance = address(this).balance;
    if (ethBalance > 0) {
      (bool success, ) = payable(owner()).call{ value: ethBalance }('');
      if (!success) revert TransferFailed();
      emit EmergencyWithdraw(owner(), ethBalance);
    }

    // 提取所有支持的ERC20代币
    address[] memory tokens = supportedTokensSet.values();
    for (uint256 i = 0; i < tokens.length; i++) {
      address token = tokens[i];
      uint256 tokenBalance = IERC20(token).balanceOf(address(this));
      if (tokenBalance > 0) {
        IERC20(token).safeTransfer(owner(), tokenBalance);
        emit EmergencyWithdrawToken(owner(), token, tokenBalance);
      }
    }
  }

  // =========================
  // 用户相关函数
  // =========================

  // 查看合约ETH余额
  function getVaultBalance() external view returns (uint256) {
    return address(this).balance;
  }

  // 查看用户在资金池中的份额
  function getUserShare(address user) external view returns (uint256) {
    return balanceOf(user);
  }

  // 添加白名单功能
  function setWhitelist(address user, bool status) external onlyOwner {
    userInfo[user].isWhitelisted = status;
  }

  // 获取用户统计信息
  function getUserStats(
    address user
  ) external view returns (uint256 depositCount, uint256 totalDeposited, uint256 currentBalance, uint256 profits) {
    UserInfo memory info = userInfo[user];
    return (info.depositCount, info.totalDeposited, balanceOf(user), userProfits[user]);
  }

  // 自行实现 isContract 函数
  function _isContract(address account) internal view returns (bool) {
    uint256 size;
    assembly {
      size := extcodesize(account)
    }
    return size > 0;
  }

  // 更新收益池
  function updateRewards(uint256 newRewards) external onlyOwner {
    if (newRewards == 0) revert InvalidAmount();
    if (totalSupply() == 0) revert InvalidAmount();

    rewardInfo.totalRewards += newRewards;

    // 计算新的每股收益（精度1e12）
    uint256 newRewardPerShare = (newRewards * 1e12) / totalSupply();
    rewardInfo.rewardPerShare += newRewardPerShare;
    rewardInfo.lastUpdateTime = block.timestamp;

    emit RewardUpdated(newRewards, rewardInfo.rewardPerShare);
  }

  // 计算待领取的收益
  function pendingRewards(address user) public view returns (uint256) {
    UserRewardInfo storage userReward = userRewardInfo[user];
    uint256 userBalance = balanceOf(user);

    if (userBalance == 0) {
      return userReward.pending;
    }

    // 计算新增收益
    uint256 accReward = (userBalance * (rewardInfo.rewardPerShare - userReward.lastRewardPerShare)) / 1e12;

    return userReward.pending + accReward;
  }

  // 领取收益
  function claimRewards() external nonReentrant {
    uint256 pending = pendingRewards(msg.sender);
    if (pending == 0) revert InvalidAmount();

    UserRewardInfo storage userReward = userRewardInfo[msg.sender];
    userReward.pending = 0;
    userReward.lastRewardPerShare = rewardInfo.rewardPerShare;
    userReward.rewardDebt += pending;

    // 转账收益（这里假设用 ETH 支付收益，也可以修改为用其他代币）
    (bool success, ) = payable(msg.sender).call{ value: pending }('');
    if (!success) revert TransferFailed();

    emit RewardClaimed(msg.sender, pending);
  }

  // 在存款和提款时更新用户收益信息
  function _updateUserReward(address user) internal {
    UserRewardInfo storage userReward = userRewardInfo[user];

    // 先结算待领取的收益
    uint256 pending = pendingRewards(user);
    userReward.pending = pending;
    userReward.lastRewardPerShare = rewardInfo.rewardPerShare;
  }

  // 存入ETH收益
  function depositProfit() external payable onlyOwner whenNotPaused {
    if (msg.value == 0) revert InvalidAmount();

    // 更新总资产
    totalAssets += calculateUSDValue(address(0), msg.value);

    emit ProfitDeposited(msg.value);
  }

  // 存入代币收益
  function depositTokenProfit(address token, uint256 amount) external onlyOwner whenNotPaused {
    if (amount == 0) revert InvalidAmount();
    if (!isSupportedToken(token)) revert TokenNotSupported();

    // 转入代币
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    // 更新总资产
    totalAssets += calculateUSDValue(token, amount);

    emit TokenProfitDeposited(token, amount);
  }

  // 添加访问控制修饰符
  modifier onlyWhitelisted() {
    if (!accessControl.isWhitelisted(msg.sender)) revert UnauthorizedAccess();
    _;
  }

  // 添加权限检查
  modifier checkLimit(uint256 amount) {
    if (!accessControl.checkLimit(msg.sender, amount)) revert UnauthorizedAccess();
    _;
  }

  // 添加 AccessControl 设置函数
  function setAccessControl(address _accessControl) external onlyOwner {
    if (_accessControl == address(0)) revert InvalidAccessControl();
    accessControl = IAccessControl(_accessControl);
    emit AccessControlSet(_accessControl);
  }

  // 添加设置 Governance 的函数
  function setGovernance(address _governance) external onlyOwner {
    if (_governance == address(0)) revert InvalidGovernance();
    address oldGovernance = governance;
    governance = _governance;
    emit GovernanceSet(oldGovernance, _governance);
  }

  // 添加修饰符
  modifier onlyGovernance() {
    if (msg.sender != governance) revert UnauthorizedAccess();
    _;
  }

  // 添加设置 Strategy 的函数
  function setStrategy(address _strategy) external onlyOwner {
    if (_strategy == address(0)) revert InvalidStrategy();
    address oldStrategy = strategy;
    strategy = _strategy;
    emit StrategySet(oldStrategy, _strategy);
  }
}
