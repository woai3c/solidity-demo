// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract PaymentProcessor {
  IERC20 public token;
  address public owner;
  uint256 public pricePerLiter = 1;

  error InsufficientBalance(uint256 available, uint256 required);
  error TransferFailed();
  error OnlyOwner();

  event PaymentReceived(address indexed from, uint256 amount, uint256 liters);
  event Withdrawal(address indexed to, uint256 amount);
  event PricePerLiterChanged(uint256 oldPrice, uint256 newPrice);

  constructor(address tokenAddress) {
    token = IERC20(tokenAddress);
    owner = msg.sender;
  }

  function pay(uint256 amount) external {
    uint256 liters = amount / pricePerLiter;
    if (token.balanceOf(msg.sender) < amount) {
      revert InsufficientBalance(token.balanceOf(msg.sender), amount);
    }

    bool success = token.transferFrom(msg.sender, address(this), amount);
    if (!success) {
      revert TransferFailed();
    }

    emit PaymentReceived(msg.sender, amount, liters);
  }

  function withdraw(uint256 amount) external {
    if (msg.sender != owner) {
      revert OnlyOwner();
    }

    if (token.balanceOf(address(this)) < amount) {
      revert InsufficientBalance(token.balanceOf(address(this)), amount);
    }

    bool success = token.transfer(owner, amount);
    if (!success) {
      revert TransferFailed();
    }

    emit Withdrawal(owner, amount);
  }

  function setPricePerLiter(uint256 newPrice) external {
    if (msg.sender != owner) {
      revert OnlyOwner();
    }

    uint256 oldPrice = pricePerLiter;
    pricePerLiter = newPrice;
    emit PricePerLiterChanged(oldPrice, newPrice);
  }
}
