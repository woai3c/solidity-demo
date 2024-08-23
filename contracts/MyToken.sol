// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';

contract MyToken is IERC20, Ownable {
  error InsufficientBalance(uint256 available, uint256 required);
  error AllowanceExceeded(uint256 available, uint256 required);

  string public name;
  string public symbol;
  uint8 public decimals = 6;
  uint256 private _totalSupply;

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  constructor(string memory name_, string memory symbol_) {
    name = name_;
    symbol = symbol_;
  }

  function totalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) external view override returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) external override returns (bool) {
    if (_balances[msg.sender] < amount) {
      revert InsufficientBalance(_balances[msg.sender], amount);
    }

    _balances[msg.sender] -= amount;
    _balances[recipient] += amount;
    emit Transfer(msg.sender, recipient, amount);
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

  function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
    if (_balances[sender] < amount) {
      revert InsufficientBalance(_balances[sender], amount);
    }

    if (_allowances[sender][msg.sender] < amount) {
      revert AllowanceExceeded(_allowances[sender][msg.sender], amount);
    }

    _balances[sender] -= amount;
    _balances[recipient] += amount;
    _allowances[sender][msg.sender] -= amount;
    emit Transfer(sender, recipient, amount);
    return true;
  }

  function mint(uint256 amount) external onlyOwner {
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
}
