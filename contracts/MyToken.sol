// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

contract MyToken is IERC20, Ownable, Pausable, ReentrancyGuard {
  // 错误定义
  error InsufficientBalance(uint256 available, uint256 required);
  error AllowanceExceeded(uint256 available, uint256 required);
  error MaxSupplyExceeded(uint256 current, uint256 required);
  error TransferToZeroAddress();
  error CooldownPeriodNotPassed(uint256 remainingTime);
  error BlacklistedAddress(address account);
  error InvalidAmount();
  error TokenTransferFailed();
  error LengthMismatch(uint256 recipientsLength, uint256 amountsLength);

  // 事件定义
  event BlacklistUpdated(address indexed account, bool isBlacklisted);
  event CooldownPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
  event TokensRecovered(address token, address to, uint256 amount);

  string public name;
  string public symbol;
  uint256 private _totalSupply;

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  // 新增安全特性
  mapping(address => bool) public blacklisted;
  mapping(address => uint256) public lastTransferTime;

  uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 6; // 10亿枚代币
  uint256 public cooldownPeriod = 1 hours;

  constructor(string memory name_, string memory symbol_, address initialOwner) Ownable(initialOwner) {
    name = name_;
    symbol = symbol_;
  }

  // 修饰器
  modifier notBlacklisted(address from, address to) {
    if (blacklisted[from] || blacklisted[to]) {
      revert BlacklistedAddress(blacklisted[from] ? from : to);
    }
    _;
  }

  modifier checkCooldown(address from) {
    if (
      from != owner() && // 排除owner
      block.timestamp < lastTransferTime[from] + cooldownPeriod
    ) {
      revert CooldownPeriodNotPassed(lastTransferTime[from] + cooldownPeriod - block.timestamp);
    }
    _;
  }

  // 基本功能实现
  function totalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) external view override returns (uint256) {
    return _balances[account];
  }

  function _transfer(address sender, address recipient, uint256 amount) internal {
    if (sender == address(0) || recipient == address(0)) revert TransferToZeroAddress();
    if (_balances[sender] < amount) revert InsufficientBalance(_balances[sender], amount);

    _balances[sender] -= amount;
    _balances[recipient] += amount;

    // 重要：确保这行代码存在 - 设置最后转账时间
    lastTransferTime[sender] = block.timestamp;

    emit Transfer(sender, recipient, amount);
  }

  function transfer(
    address recipient,
    uint256 amount
  )
    external
    override
    whenNotPaused
    notBlacklisted(msg.sender, recipient)
    checkCooldown(msg.sender)
    nonReentrant
    returns (bool)
  {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) external override returns (bool) {
    _allowances[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  )
    external
    override
    whenNotPaused
    notBlacklisted(sender, recipient)
    checkCooldown(sender)
    nonReentrant
    returns (bool)
  {
    if (_balances[sender] < amount) {
      revert InsufficientBalance(_balances[sender], amount);
    }

    if (_allowances[sender][msg.sender] < amount) {
      revert AllowanceExceeded(_allowances[sender][msg.sender], amount);
    }

    _allowances[sender][msg.sender] -= amount;
    _transfer(sender, recipient, amount);
    return true;
  }

  function mint(uint256 amount) external onlyOwner {
    if (_totalSupply + amount > MAX_SUPPLY) {
      revert MaxSupplyExceeded(_totalSupply, _totalSupply + amount);
    }

    _balances[msg.sender] += amount;
    _totalSupply += amount;
    emit Transfer(address(0), msg.sender, amount);
  }

  function burn(uint256 amount) external {
    if (_balances[msg.sender] < amount) {
      revert InsufficientBalance(_balances[msg.sender], amount);
    }

    _balances[msg.sender] -= amount;
    _totalSupply -= amount;
    emit Transfer(msg.sender, address(0), amount);
  }

  // 新增管理功能
  function setCooldownPeriod(uint256 newPeriod) external onlyOwner {
    emit CooldownPeriodUpdated(cooldownPeriod, newPeriod);
    cooldownPeriod = newPeriod;
  }

  function updateBlacklist(address account, bool isBlacklisted) external onlyOwner {
    blacklisted[account] = isBlacklisted;
    emit BlacklistUpdated(account, isBlacklisted);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  // 紧急代币回收
  function recoverTokens(address tokenAddress, address to, uint256 amount) external onlyOwner {
    // 检查
    if (to == address(0)) revert TransferToZeroAddress();
    if (amount == 0) revert InvalidAmount();

    // 效果
    emit TokensRecovered(tokenAddress, to, amount);

    // 交互
    if (tokenAddress == address(this)) {
      _transfer(address(this), to, amount);
    } else {
      bool success = IERC20(tokenAddress).transfer(to, amount);
      if (!success) revert TokenTransferFailed();
    }
  }

  // 批量转账优化
  function batchTransfer(
    address[] calldata recipients,
    uint256[] calldata amounts
  ) external whenNotPaused nonReentrant returns (bool) {
    if (recipients.length != amounts.length) revert LengthMismatch(recipients.length, amounts.length);

    uint256 totalAmount = 0;
    for (uint256 i = 0; i < amounts.length; i++) {
      totalAmount += amounts[i];
    }

    if (_balances[msg.sender] < totalAmount) {
      revert InsufficientBalance(_balances[msg.sender], totalAmount);
    }

    for (uint256 i = 0; i < recipients.length; i++) {
      _transfer(msg.sender, recipients[i], amounts[i]);
    }

    return true;
  }
}
