// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MockAttacker {
  IERC20 public token;
  uint256 public attackCount;
  address public owner;
  bool public attackInProgress;

  constructor(address _token) {
    token = IERC20(_token);
    owner = msg.sender;
  }

  // 开始攻击的入口函数
  function attack() external {
    // 确保攻击者合约有足够代币
    uint256 balance = token.balanceOf(address(this));
    require(balance >= 100, 'Insufficient balance for attack');

    // 设置攻击标志
    attackInProgress = true;

    // 尝试转账，这将调用我们的 receive 函数
    token.transfer(msg.sender, 100);

    // 攻击结束
    attackInProgress = false;
  }

  // 这是关键的重入攻击点
  receive() external payable {
    // 只有在攻击进行中且攻击次数小于设定值时执行
    if (attackInProgress && attackCount < 3) {
      attackCount++;

      // 尝试重入攻击 - 再次调用transfer
      token.transfer(owner, 10);
    }
  }
}
