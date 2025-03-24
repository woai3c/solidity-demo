// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from 'forge-std/Test.sol';
import { MyToken } from '../../contracts/MyToken.sol';

contract MyTokenFuzzTest is Test {
  MyToken public token;
  address public owner;

  function setUp() public {
    owner = address(this);
    token = new MyToken('Test Token', 'TEST', owner);
    uint256 amount = 1000 * 10 ** token.decimals();
    token.mint(amount);
  }

  // 模糊测试 - 随机地址和金额的转账
  function testFuzzTransfer(address recipient, uint256 amount) public {
    // 排除无效情况
    vm.assume(recipient != address(0) && recipient != owner);

    // 修改：限制金额在实际余额范围内
    uint256 ownerBalance = token.balanceOf(owner);
    amount = bound(amount, 1, ownerBalance);

    uint256 initialOwnerBalance = token.balanceOf(owner);
    token.transfer(recipient, amount);

    assertEq(token.balanceOf(recipient), amount);
    assertEq(token.balanceOf(owner), initialOwnerBalance - amount);
  }

  // 模糊测试 - 批量转账安全性
  function testFuzzBatchTransferSafety(uint256 recipientCount) public {
    // 限制数组大小以避免gas问题
    recipientCount = bound(recipientCount, 1, 100);

    address[] memory recipients = new address[](recipientCount);
    uint256[] memory amounts = new uint256[](recipientCount);

    uint256 totalAmount = 0;

    for (uint256 i = 0; i < recipientCount; i++) {
      // 使用确定但不同的地址
      recipients[i] = address(uint160(i + 1000));
      // 随机1-10代币
      amounts[i] = (i + 1) * 1 ether;
      totalAmount += amounts[i];
    }

    // 确保有足够代币
    if (totalAmount > token.balanceOf(owner)) {
      return;
    }

    uint256 initialBalance = token.balanceOf(owner);

    // 执行批量转账
    for (uint256 i = 0; i < recipientCount; i++) {
      token.transfer(recipients[i], amounts[i]);
    }

    // 验证所有接收者都收到了正确金额
    for (uint256 i = 0; i < recipientCount; i++) {
      assertEq(token.balanceOf(recipients[i]), amounts[i]);
    }

    // 验证总余额变化
    assertEq(token.balanceOf(owner), initialBalance - totalAmount);
  }
}
