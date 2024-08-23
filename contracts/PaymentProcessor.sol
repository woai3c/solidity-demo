// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract PaymentProcessor is Ownable {
  using SafeERC20 for IERC20;

  IERC20 public token;
  uint256 public pricePerLiter = 1;

  error InsufficientBalance(uint256 available, uint256 required);
  error TransferFailed();

  event PaymentReceived(address indexed from, uint256 amount, uint256 liters);
  event Withdrawal(address indexed to, uint256 amount);
  event PricePerLiterChanged(uint256 oldPrice, uint256 newPrice);

  constructor(address tokenAddress) {
    token = IERC20(tokenAddress);
  }

  function pay(uint256 amount) external {
    uint256 liters = amount / pricePerLiter;
    if (token.balanceOf(msg.sender) < amount) {
      revert InsufficientBalance(token.balanceOf(msg.sender), amount);
    }

    token.safeTransferFrom(msg.sender, address(this), amount);

    emit PaymentReceived(msg.sender, amount, liters);
  }

  function withdraw(uint256 amount) external onlyOwner {
    if (token.balanceOf(address(this)) < amount) {
      revert InsufficientBalance(token.balanceOf(address(this)), amount);
    }

    token.safeTransfer(owner(), amount);

    emit Withdrawal(owner(), amount);
  }

  function setPricePerLiter(uint256 newPrice) external onlyOwner {
    uint256 oldPrice = pricePerLiter;
    pricePerLiter = newPrice;
    emit PricePerLiterChanged(oldPrice, newPrice);
  }
}
