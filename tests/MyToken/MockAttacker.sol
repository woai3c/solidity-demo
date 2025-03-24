// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MockAttacker {
  IERC20 public token;
  bool private attacking;
  uint256 public attackCount;

  constructor(address _token) {
    token = IERC20(_token);
  }

  function attack() external {
    uint256 balance = token.balanceOf(address(this));
    attackCount = 0;
    attacking = true;
    token.transfer(msg.sender, balance);
  }

  // 尝试重入函数
  receive() external payable {
    if (attacking && attackCount < 1) {
      attackCount++;
      token.transfer(msg.sender, 10);
    }
  }

  // ERC20接收回调函数（如果MyToken实现了这个）
  function onERC20Received(address, address, uint256, bytes calldata) external returns (bytes4) {
    if (attacking && attackCount < 1) {
      attackCount++;
      token.transfer(msg.sender, 10);
    }
    return bytes4(keccak256('onERC20Received(address,address,uint256,bytes)'));
  }
}
