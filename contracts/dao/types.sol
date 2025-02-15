// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPriceFeed {
  function getPrice(address token) external view returns (uint256);
  function addPriceFeed(address token, address feed) external;
}

interface IStrategy {
  // 错误定义
  error InvalidToken(address token);
  error InsufficientBalance(uint256 requested, uint256 available);
  error StrategyFailure(string reason);

  // 事件定义
  event Invested(address indexed token, uint256 amount, uint256 timestamp);
  event Withdrawn(address indexed token, uint256 amount, uint256 timestamp);
  event Harvested(uint256 indexed totalValue, uint256 timestamp);

  // 核心功能
  function invest(address token, uint256 amount) external returns (bool);
  function withdraw(address token, uint256 amount) external returns (bool);
  function harvest() external returns (uint256 totalValue);

  // 查询功能
  function estimateReturns() external view returns (uint256 totalValue);
  function getTokenValue(address token) external view returns (uint256 value);
  function isSupported(address token) external view returns (bool);
}

interface IUpgradeable {
  function initialize(bytes memory data) external;
  function upgradeTo(address newImplementation) external;
  function upgradeToAndCall(address newImplementation, bytes memory data) external;
}
