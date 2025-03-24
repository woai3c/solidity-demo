// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from 'forge-std/Test.sol';
import { MyToken } from '../../contracts/MyToken.sol';
import { MockAttacker } from './MockAttacker.sol';

contract MyTokenSecurityTest is Test {
  MyToken public token;
  address public owner;
  address public user1;
  address public user2;
  MockAttacker public attacker;

  function setUp() public {
    owner = address(this);
    user1 = vm.addr(1);
    user2 = vm.addr(2);

    token = new MyToken('Test Token', 'TEST', owner);
    token.mint(1000 * 10 ** 6);

    // 设置一个较短的冷却期，方便测试
    token.setCooldownPeriod(1); // 设置为1秒

    attacker = new MockAttacker(address(token));
    token.transfer(address(attacker), 100 * 10 ** 6);
  }

  // 重入测试
  function testReentrancyProtection() public {
    // 设置冷却期为最小值方便测试
    token.setCooldownPeriod(1);

    // 跳过冷却期
    skip(2);

    // 执行攻击
    attacker.attack();

    // 检查攻击计数为0，证明防护成功
    assertEq(attacker.attackCount(), 0, 'Reentrancy protection failed');
  }

  // 模糊测试黑名单功能
  function testFuzzBlacklist(address randomUser) public {
    vm.assume(randomUser != address(0) && randomUser != owner);

    token.transfer(randomUser, 100);
    token.updateBlacklist(randomUser, true);

    vm.prank(randomUser);
    vm.expectRevert(abi.encodeWithSelector(MyToken.BlacklistedAddress.selector, randomUser));
    token.transfer(user1, 10);

    token.updateBlacklist(randomUser, false);

    // 新增：跳过冷却期
    skip(token.cooldownPeriod() + 1);

    vm.prank(randomUser);
    token.transfer(user1, 10);
  }

  // 冷却期测试
  function testCooldown() public {
    token.setCooldownPeriod(60);
    token.transfer(user1, 100);

    vm.prank(user1);
    vm.expectRevert();
    token.transfer(user2, 50);

    skip(61); // 简单地跳过时间

    vm.prank(user1);
    token.transfer(user2, 50);
  }
}
