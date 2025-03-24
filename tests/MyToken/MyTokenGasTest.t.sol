// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from 'forge-std/Test.sol';
import { MyToken } from '../../contracts/MyToken.sol';

contract MyTokenGasTest is Test {
  MyToken public token;

  function setUp() public {
    token = new MyToken('Test Token', 'TEST', address(this));
    token.mint(1000 * 10 ** 6);
  }

  // 测量单次转账gas成本
  function testTransferGas() public {
    token.transfer(address(0xABCD), 100);
  }

  // 测量批量转账gas成本
  function testMultipleTransfersGas() public {
    for (uint i = 0; i < 5; i++) {
      token.transfer(address(uint160(i + 1000)), 100);
    }
  }

  // 比较授权模式的gas成本
  function testApproveAndTransferGas() public {
    address spender = address(0xBEEF);

    // 第一种模式：先授权，后转账
    token.approve(spender, 1000);

    vm.prank(spender);
    token.transferFrom(address(this), address(0xDEAD), 500);

    // 重置状态
    vm.roll(block.number + 1);

    // 第二种模式：使用permit (如果合约支持)
    // token.permit(...) // 假设合约有permit功能

    vm.prank(spender);
    token.transferFrom(address(this), address(0xDEAD), 500);
  }
}
