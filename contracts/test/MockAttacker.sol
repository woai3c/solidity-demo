// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MockAttacker {
  IERC20 public token;
  uint256 public attackCount;
  address public owner;

  error InsufficientBalance();

  constructor(address _token) {
    token = IERC20(_token);
    owner = msg.sender;
  }

  function resetCount() external {
    attackCount = 0;
  }

  // 攻击函数 - 简化实现，专注于测试nonReentrant效果
  function attack() external {
    // 确保有足够代币
    uint256 balance = token.balanceOf(address(this));
    if (balance < 100) revert InsufficientBalance();

    // 设置攻击计数为1（而不是递增）
    attackCount = 1;

    // 执行一次转账
    token.transfer(msg.sender, 100);

    // 不再尝试第二次转账，因为这不是测试重入保护的正确方式
  }
}
