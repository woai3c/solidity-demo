// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ITransparentUpgradeableProxy } from './types.sol';

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';
import { Address } from '@openzeppelin/contracts/utils/Address.sol';
import { Role } from './types.sol';
import { RoleControl } from './utils/RoleControl.sol';
/**
 * @title ProxyAdmin
 * @dev 管理代理合约的升级和管理
 */
contract ProxyAdmin is Ownable, ReentrancyGuard, Pausable, RoleControl {
  using Address for address;

  // 错误定义
  error NotAContract(address implementation);
  error InvalidProxy(address proxy);
  error AlreadyInitialized(address proxy);
  error UpgradeFailed(address proxy, address implementation);
  error InitializationFailed(address proxy, bytes data);
  error TimelockNotExpired(uint256 current, uint256 unlock);
  error InvalidImplementation(address implementation);
  error NotRegisteredProxy(address proxy);
  error AlreadyRegistered(address proxy);

  // 状态变量
  mapping(address => address) public implementations; // 代理合约 => 实现合约
  mapping(address => uint256) public upgradeTimeLocks; // 升级时间锁
  mapping(address => bool) public registeredProxies; // 已注册的代理
  uint256 public constant UPGRADE_TIMELOCK = 2 days; // 升级等待期
  uint256 public constant GRACE_PERIOD = 3 days; // 宽限期
  mapping(address => address) public getProxyImplementation; // 存储代理合约的实现地址

  // 事件定义
  event ProxyRegistered(address indexed proxy, address indexed implementation);
  event ProxyUpgraded(address indexed proxy, address indexed oldImpl, address indexed newImpl);
  event ImplementationAdded(address indexed implementation);
  event UpgradeScheduled(address indexed proxy, address indexed implementation, uint256 unlockTime);
  event UpgradeCancelled(address indexed proxy);

  constructor() Ownable(msg.sender) {
    _pause(); // 初始暂停状态
  }

  // 管理功能
  function registerProxy(
    address proxy,
    address implementation,
    bytes calldata initData
  ) external onlyRole(Role.ADMIN) whenNotPaused nonReentrant {
    if (implementation.code.length == 0) revert NotAContract(implementation);
    if (registeredProxies[proxy]) revert AlreadyInitialized(proxy);

    // Register
    registeredProxies[proxy] = true;
    implementations[proxy] = implementation;
    getProxyImplementation[proxy] = implementation;

    if (initData.length > 0) {
      // Use our interface to call upgradeToAndCall
      ITransparentUpgradeableProxy(payable(proxy)).upgradeToAndCall(implementation, initData);
    }
    emit ProxyRegistered(proxy, implementation);
  }

  function scheduleUpgrade(address proxy, address newImplementation) external onlyRole(Role.ADMIN) whenNotPaused {
    if (!registeredProxies[proxy]) revert InvalidProxy(proxy);
    if (newImplementation.code.length == 0) revert NotAContract(newImplementation);
    if (implementations[proxy] == newImplementation) revert InvalidImplementation(newImplementation);

    upgradeTimeLocks[proxy] = block.timestamp + UPGRADE_TIMELOCK;

    emit UpgradeScheduled(proxy, newImplementation, upgradeTimeLocks[proxy]);
  }

  function upgrade(address proxy, address newImplementation) external onlyOwner whenNotPaused nonReentrant {
    uint256 unlockTime = upgradeTimeLocks[proxy];
    if (block.timestamp < unlockTime || block.timestamp > unlockTime + GRACE_PERIOD) {
      revert TimelockNotExpired(block.timestamp, unlockTime);
    }

    address oldImplementation = implementations[proxy];

    // Use our interface to call upgradeTo
    ITransparentUpgradeableProxy(payable(proxy)).upgradeTo(newImplementation);

    implementations[proxy] = newImplementation;
    getProxyImplementation[proxy] = newImplementation;
    delete upgradeTimeLocks[proxy];

    emit ProxyUpgraded(proxy, oldImplementation, newImplementation);
  }

  function cancelUpgrade(address proxy) external onlyOwner {
    delete upgradeTimeLocks[proxy];
    emit UpgradeCancelled(proxy);
  }

  // 查询功能
  function getImplementation(address proxy) external view returns (address) {
    return implementations[proxy];
  }

  function getUpgradeStatus(
    address proxy
  ) external view returns (bool isRegistered, address currentImpl, uint256 unlockTime, bool canUpgrade) {
    isRegistered = registeredProxies[proxy];
    currentImpl = implementations[proxy];
    unlockTime = upgradeTimeLocks[proxy];
    canUpgrade = block.timestamp >= unlockTime && block.timestamp <= unlockTime + GRACE_PERIOD;
  }

  // 暂停功能
  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }
}
