// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

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

  // 跟踪合约是否已初始化
  bool private _roleControlInitialized;

  // 构造函数 - 用于非可升级合约
  constructor() {
    _initializeRoleControl();
  }

  // 初始化函数 - 用于可升级合约
  function __RoleControl_init() internal {
    __RoleControl_init_unchained();
  }

  function __RoleControl_init_unchained() internal {
    _initializeRoleControl();
  }

  // 内部初始化逻辑 - 被构造函数和初始化函数共用
  function _initializeRoleControl() private {
    if (!_roleControlInitialized) {
      userRoles[msg.sender] = Role.SUPER_ADMIN;
      _roleControlInitialized = true;
    }
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
