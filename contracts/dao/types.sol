// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPriceFeed {
  function getPrice(address token) external view returns (uint256);
  function addPriceFeed(address token, address feed) external;
}
