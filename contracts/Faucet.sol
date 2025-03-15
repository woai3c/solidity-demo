// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';

contract Faucet is Ownable, ReentrancyGuard, Pausable {
  using SafeERC20 for IERC20;

  IERC20 public token;
  uint256 public distributionAmount;
  uint256 public constant DISTRIBUTION_INTERVAL = 1 days;
  mapping(address => uint256) public lastDistributionTime;

  error AlreadyDistributedInDay(address to, uint256 amount);
  error InsufficientBalance(uint256 available, uint256 required);
  error InvalidRecipient();
  error ContractPaused();

  event Distribution(address indexed to, uint256 amount, uint256 timestamp);
  event DistributionAmountChanged(uint256 oldAmount, uint256 newAmount);
  event FaucetPaused(address pauser);
  event FaucetUnpaused(address unpauser);

  constructor(address tokenAddress, address initialOwner, uint256 initialDistributionAmount) Ownable(initialOwner) {
    token = IERC20(tokenAddress);
    distributionAmount = initialDistributionAmount;
  }

  function distributeToken(address to) external onlyOwner nonReentrant {
    // Check if the contract is paused
    if (paused()) {
      revert ContractPaused();
    }

    if (to == address(0)) revert InvalidRecipient();

    uint256 currentTime = block.timestamp;
    uint256 lastTime = lastDistributionTime[to];

    if (currentTime < lastTime + DISTRIBUTION_INTERVAL) {
      revert AlreadyDistributedInDay(to, distributionAmount);
    }

    uint256 ownerBalance = token.balanceOf(owner());
    if (ownerBalance < distributionAmount) {
      revert InsufficientBalance(ownerBalance, distributionAmount);
    }

    token.safeTransferFrom(owner(), to, distributionAmount);
    lastDistributionTime[to] = currentTime;

    emit Distribution(to, distributionAmount, currentTime);
  }

  function setDistributionAmount(uint256 newAmount) external onlyOwner {
    uint256 oldAmount = distributionAmount;
    distributionAmount = newAmount;
    emit DistributionAmountChanged(oldAmount, newAmount);
  }

  function pause() external onlyOwner {
    _pause();
    emit FaucetPaused(msg.sender);
  }

  function unpause() external onlyOwner {
    _unpause();
    emit FaucetUnpaused(msg.sender);
  }

  // Public function to check if the contract is paused
  function isPaused() public view returns (bool) {
    return paused();
  }
}
