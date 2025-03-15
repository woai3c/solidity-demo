// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Role } from '../types.sol';

/**
 * @title RoleControl
 * @dev 基础角色控制合约，提供角色管理功能
 */
abstract contract RoleControl {
  // 错误定义
  error UnauthorizedAccess();
  error ZeroAddress();
  error InvalidRole();

  // 角色映射
  mapping(address => Role) public userRoles;

  // 事件
  event RoleGranted(address indexed account, Role indexed role);
  event RoleRevoked(address indexed account, Role indexed role);

  // 构造函数 - 用于非可升级合约
  constructor() {
    userRoles[msg.sender] = Role.SUPER_ADMIN;
  }

  // 修改器
  modifier onlyRole(Role requiredRole) {
    if (userRoles[msg.sender] < requiredRole) revert UnauthorizedAccess();
    _;
  }

  // 角色管理函数
  function setUserRole(address user, Role role) external onlyRole(Role.SUPER_ADMIN) {
    if (user == address(0)) revert ZeroAddress();
    userRoles[user] = role;
    emit RoleGranted(user, role);
  }

  function revokeRole(address user) external onlyRole(Role.SUPER_ADMIN) {
    if (user == address(0)) revert ZeroAddress();
    if (userRoles[user] == Role.NONE) revert InvalidRole();

    Role oldRole = userRoles[user];
    delete userRoles[user];
    emit RoleRevoked(user, oldRole);
  }

  // 查询函数
  function hasRole(address user, Role role) public view returns (bool) {
    return userRoles[user] >= role;
  }

  function getUserRole(address user) public view returns (Role) {
    return userRoles[user];
  }
}
