// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AggregatorV3Interface } from '@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { IPriceFeed } from './types.sol';

contract ChainlinkPriceFeed is IPriceFeed, Ownable {
  mapping(address => address) public priceFeeds;

  constructor() Ownable(msg.sender) {
    // Sepolia 测试网上的 ETH/USD 喂价合约
    priceFeeds[address(0)] = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    // 可以添加其他代币的喂价地址
  }

  function getPrice(address token) external view override returns (uint256) {
    address feedAddress = priceFeeds[token];
    require(feedAddress != address(0), 'Price feed not found');

    AggregatorV3Interface priceFeed = AggregatorV3Interface(feedAddress);
    (
      ,
      /* uint80 roundID */ int256 price,
      ,
      /* uint256 startedAt */ uint256 timeStamp /* uint80 answeredInRound */,

    ) = priceFeed.latestRoundData();

    require(timeStamp > block.timestamp - 3600, 'Stale price');
    require(price > 0, 'Invalid price');

    return uint256(price);
  }

  // 添加或更新价格源
  function addPriceFeed(address token, address feed) external onlyOwner {
    require(feed != address(0), 'Invalid feed address');
    priceFeeds[token] = feed;
    emit PriceFeedUpdated(token, feed);
  }

  event PriceFeedUpdated(address token, address feed);
}
