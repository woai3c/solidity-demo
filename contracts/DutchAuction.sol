// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DutchAuction {
  address public seller;
  uint256 public startTime;
  uint256 public startPrice;
  uint256 public reservePrice;
  uint256 public duration;

  constructor(uint256 startPrice_, uint256 reservePrice_, uint256 duration_) {
    seller = msg.sender;
    startTime = block.timestamp;
    startPrice = startPrice_;
    reservePrice = reservePrice_;
    duration = duration_;
  }

  function getCurrentPrice() public view returns (uint256) {
    uint256 curTime = block.timestamp;
    require(curTime < startTime + duration, 'Auction was ended');
    uint256 diffTime = curTime - startTime;
    return startPrice - ((startPrice - reservePrice) * diffTime) / duration;
  }
}
