// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';

contract DutchAuction is Ownable {
  address public seller;
  uint256 public startTime;
  uint256 public startPrice;
  uint256 public reservePrice;
  uint256 public duration;
  bool public isAuctionEnded;
  IERC20 public paymentToken;

  error AuctionWasEnded();
  error InsufficientFunds(uint256 value, uint256 curPrice);
  error TokenTransferFailed();
  error TokenRefundFailed();
  error AuctionNotStarted();

  event AuctionEnded(address buyer, uint256 price);
  event AuctionStarted(address seller, uint256 startPrice, uint256 reservePrice, uint256 duration);
  event AuctionConfigured(uint256 startPrice, uint256 reservePrice, uint256 duration);
  event TokenTransfer(address from, address to, uint256 amount);
  event TokenRefund(address to, uint256 amount);

  constructor(address paymentTokenAddress) Ownable(msg.sender) {
    seller = msg.sender;
    paymentToken = IERC20(paymentTokenAddress);
    isAuctionEnded = false;
  }

  function configureAuction(uint256 startPrice_, uint256 reservePrice_, uint256 duration_) external onlyOwner {
    startPrice = startPrice_;
    reservePrice = reservePrice_;
    duration = duration_;
    emit AuctionConfigured(startPrice, reservePrice, duration);
  }

  function startAuction() external onlyOwner {
    startTime = block.timestamp;
    emit AuctionStarted(seller, startPrice, reservePrice, duration);
  }

  function getCurrentPrice() public view returns (uint256) {
    if (startTime == 0) {
      revert AuctionNotStarted();
    }

    uint256 curTime = block.timestamp;
    if (isAuctionEnded || curTime >= startTime + duration) {
      return reservePrice;
    }

    uint256 diffTime = curTime - startTime;
    return startPrice - ((startPrice - reservePrice) * diffTime) / duration;
  }

  function purchase(uint256 amount) external {
    if (startTime == 0) {
      revert AuctionNotStarted();
    }

    if (isAuctionEnded) {
      revert AuctionWasEnded();
    }

    uint256 curPrice = getCurrentPrice();
    if (amount < curPrice) {
      revert InsufficientFunds(amount, curPrice);
    }

    // Checks-Effects-Interactions pattern
    isAuctionEnded = true;
    emit AuctionEnded(msg.sender, curPrice);

    // Transfer tokens to the seller
    bool success = paymentToken.transferFrom(msg.sender, seller, curPrice);
    if (!success) {
      revert TokenTransferFailed();
    }

    emit TokenTransfer(msg.sender, seller, curPrice);

    // Refund excess amount
    if (amount > curPrice) {
      success = paymentToken.transferFrom(msg.sender, msg.sender, amount - curPrice);
      if (!success) {
        revert TokenRefundFailed();
      }

      emit TokenRefund(msg.sender, amount - curPrice);
    }
  }
}
