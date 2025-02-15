// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MerkleProof } from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

contract AccessControl is Ownable, Pausable, ReentrancyGuard {
  // 错误定义
  error InvalidProof();
  error InvalidTier(uint256 tier);
  error InvalidLimit(uint256 provided, uint256 max);
  error NotWhitelisted(address user);
  error AlreadyWhitelisted(address user);
  error TierLocked(address user);
  error ExceedsLimit(uint256 requested, uint256 available);

  // 常量
  uint256 public constant MAX_TIER = 4; // 最大等级
  uint256 public constant TIER_LOCK_PERIOD = 7 days; // 等级锁定期
  uint256 public constant MAX_WHITELIST_SIZE = 10000; // 白名单容量限制

  // 状态变量
  bytes32 public merkleRoot; // 白名单默克尔树根
  mapping(address => uint256) public userTier; // 用户等级
  mapping(uint256 => uint256) public tierLimits; // 等级限额
  mapping(address => uint256) public lastTierUpdate; // 最后更新时间
  mapping(address => bool) public isWhitelisted; // 白名单状态
  uint256 public whitelistCount; // 白名单计数

  // 事件
  event WhitelistUpdated(bytes32 indexed newRoot, uint256 timestamp);
  event TierUpdated(address indexed user, uint256 oldTier, uint256 newTier);
  event TierLimitUpdated(uint256 indexed tier, uint256 oldLimit, uint256 newLimit);
  event UserWhitelisted(address indexed user, uint256 tier);
  event UserBlacklisted(address indexed user);

  constructor(bytes32 _merkleRoot) Ownable(msg.sender) {
    merkleRoot = _merkleRoot;

    // 初始化默认等级限额
    tierLimits[1] = 10_000 ether; // Tier 1: 10,000 ETH
    tierLimits[2] = 50_000 ether; // Tier 2: 50,000 ETH
    tierLimits[3] = 200_000 ether; // Tier 3: 200,000 ETH
    tierLimits[4] = type(uint256).max; // Tier 4: 无限制
  }

  // 核心功能
  function verifyWhitelist(bytes32[] calldata proof, address user) external view returns (bool) {
    bytes32 leaf = keccak256(abi.encodePacked(user));
    return MerkleProof.verify(proof, merkleRoot, leaf);
  }

  function updateUserTier(address user, uint256 newTier, bytes32[] calldata proof) external whenNotPaused nonReentrant {
    // 验证新等级
    if (newTier == 0 || newTier > MAX_TIER) revert InvalidTier(newTier);

    // 验证冷却期
    if (block.timestamp < lastTierUpdate[user] + TIER_LOCK_PERIOD) revert TierLocked(user);

    // 验证白名单证明
    if (!_verifyProof(proof, user)) revert InvalidProof();

    uint256 oldTier = userTier[user];
    userTier[user] = newTier;
    lastTierUpdate[user] = block.timestamp;

    emit TierUpdated(user, oldTier, newTier);
  }

  function checkLimit(address user, uint256 amount) external view returns (bool) {
    uint256 tier = userTier[user];
    if (tier == 0) return false;
    return amount <= tierLimits[tier];
  }

  // 管理功能
  function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
    merkleRoot = newRoot;
    emit WhitelistUpdated(newRoot, block.timestamp);
  }

  function updateTierLimit(uint256 tier, uint256 newLimit) external onlyOwner {
    if (tier == 0 || tier > MAX_TIER) revert InvalidTier(tier);

    uint256 oldLimit = tierLimits[tier];
    tierLimits[tier] = newLimit;

    emit TierLimitUpdated(tier, oldLimit, newLimit);
  }

  function addToWhitelist(address user, uint256 tier, bytes32[] calldata proof) external whenNotPaused nonReentrant {
    if (isWhitelisted[user]) revert AlreadyWhitelisted(user);
    if (whitelistCount >= MAX_WHITELIST_SIZE) revert ExceedsLimit(whitelistCount + 1, MAX_WHITELIST_SIZE);
    if (!_verifyProof(proof, user)) revert InvalidProof();

    isWhitelisted[user] = true;
    userTier[user] = tier;
    whitelistCount++;

    emit UserWhitelisted(user, tier);
  }

  function removeFromWhitelist(address user) external onlyOwner {
    if (!isWhitelisted[user]) revert NotWhitelisted(user);

    isWhitelisted[user] = false;
    delete userTier[user];
    whitelistCount--;

    emit UserBlacklisted(user);
  }

  // 内部函数
  function _verifyProof(bytes32[] calldata proof, address user) internal view returns (bool) {
    bytes32 leaf = keccak256(abi.encodePacked(user));
    return MerkleProof.verify(proof, merkleRoot, leaf);
  }

  // 暂停功能
  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }
}
