// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MyToken is IERC20 {
  error InsufficientBalance(uint256 available, uint256 required);
  error AllowanceExceeded(uint256 available, uint256 required);

  mapping(address => uint256) public override balanceOf;
  mapping(address => mapping(address => uint256)) public override allowance;
  uint256 public override totalSupply;
  string public name;
  string public symbol;
  uint8 public decimals = 18;

  constructor(string memory name_, string memory symbol_) {
    name = name_;
    symbol = symbol_;
  }

  function totalSupply() external view override returns (uint256) {
    return totalSupply;
  }

  function balanceOf(address account) external view override returns (uint256) {
    return balanceOf[account];
  }

  function transfer(address recipient, uint256 amount) external override returns (bool) {
    if (balanceOf[msg.sender] < amount) {
      revert InsufficientBalance(balanceOf[msg.sender], amount);
    }

    balanceOf[msg.sender] -= amount;
    balanceOf[recipient] += amount;
    emit Transfer(msg.sender, recipient, amount);
    return true;
  }

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowance[owner][spender];
  }

  function approve(address spender, uint256 amount) external override returns (bool) {
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
    if (balanceOf[sender] < amount) {
      revert InsufficientBalance(balanceOf[sender], amount);
    }

    if (allowance[sender][msg.sender] < amount) {
      revert AllowanceExceeded(allowance[sender][msg.sender], amount);
    }

    balanceOf[sender] -= amount;
    balanceOf[recipient] += amount;
    allowance[sender][msg.sender] -= amount;
    emit Transfer(sender, recipient, amount);
    return true;
  }

  function mint(uint256 amount) external {
    balanceOf[msg.sender] += amount;
    totalSupply += amount;
    emit Transfer(address(0), msg.sender, amount);
  }

  function burn(uint256 amount) external {
    if (balanceOf[msg.sender] < amount) {
      revert InsufficientBalance(balanceOf[msg.sender], amount);
    }

    balanceOf[msg.sender] -= amount;
    totalSupply -= amount;
    emit Transfer(msg.sender, address(0), amount);
  }
}
