// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AggregatorV3Interface } from '@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { IPriceFeed } from '../types.sol';
import { RoleControl } from './RoleControl.sol';
import { Role } from '../types.sol';

contract ChainlinkPriceFeed is IPriceFeed, Ownable, RoleControl {
  // 自定义错误
  error PriceFeedNotFound();
  error StalePrice();
  error InvalidPrice();
  error InvalidFeedAddress();

  mapping(address => address) public priceFeeds;

  constructor() Ownable(msg.sender) {
    // Sepolia 测试网上的 ETH/USD 喂价合约
    priceFeeds[address(0)] = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    // 可以添加其他代币的喂价地址
  }

  function getPrice(address token) external view override returns (uint256) {
    address feedAddress = priceFeeds[token];
    if (feedAddress == address(0)) revert PriceFeedNotFound();

    AggregatorV3Interface priceFeed = AggregatorV3Interface(feedAddress);
    (
      ,
      /* uint80 roundID */ int256 price,
      ,
      /* uint256 startedAt */ uint256 timeStamp /* uint80 answeredInRound */,

    ) = priceFeed.latestRoundData();

    if (timeStamp <= block.timestamp - 3600) revert StalePrice();
    if (price <= 0) revert InvalidPrice();

    return uint256(price);
  }

  // 添加或更新价格源
  function addPriceFeed(address token, address feed) external onlyRole(Role.ADMIN) {
    if (feed == address(0)) revert InvalidFeedAddress();
    priceFeeds[token] = feed;
    emit PriceFeedUpdated(token, feed);
  }

  event PriceFeedUpdated(address token, address feed);
}
