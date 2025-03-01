// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { EIP712Upgradeable } from '@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { ECDSA } from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol'; // 使用非升级版本
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import { AccessControlUpgradeable } from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { Initializable } from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { RoleControl } from './utils/RoleControl.sol';
import { Role } from './utils/RoleControl.sol';

import { IStrategy } from './types.sol';

contract Governance is
  Initializable,
  EIP712Upgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  OwnableUpgradeable,
  UUPSUpgradeable,
  RoleControl
{
  using SafeERC20 for IERC20;

  // 错误定义优化 - 添加更多信息
  error InvalidProposal(string reason);
  error ProposalNotExists(uint256 proposalId);
  error InvalidSignature(address signer);
  error AlreadyVoted(address voter, uint256 proposalId);
  error VotingClosed(uint256 currentBlock, uint256 deadline);
  error QuorumNotReached(uint256 current, uint256 required);
  error ExecutionFailed(string reason);
  error ProposalAlreadyExecuted(uint256 proposalId);
  error ProposalExpired(uint256 proposalId);
  error NotEnoughVotingPower(uint256 required, uint256 actual);
  error InvalidTarget();
  error InvalidArrayLength();
  error NotAContract(address target);
  error AlreadyExecuted();
  error ProposalNotPassed(uint256 forVotes, uint256 againstVotes);
  error InvalidDelegation(string reason);
  error AlreadyQueued();
  error DelayTooLong();
  error ArithmeticOverflow(uint256 a, uint256 b);

  // 提案状态枚举 - 添加新状态
  enum ProposalState {
    Pending, // 等待投票开始
    Active, // 投票进行中
    Defeated, // 投票失败
    Succeeded, // 投票成功
    Executed, // 已执行
    Expired,
    Canceled,
    Queued
  }

  // 优化提案结构 - 添加新字段
  struct Proposal {
    address proposer;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    uint256 startBlock;
    uint256 endBlock;
    uint256 forVotes;
    uint256 againstVotes;
    bool executed;
    bool canceled;
    uint256 eta;
    string description; // 添加描述字段
    mapping(address => bool) hasVoted;
  }

  // 优化提案存储
  struct ProposalCore {
    uint32 startBlock;
    uint32 endBlock;
    uint64 eta;
    bool executed;
    bool canceled;
  }
  mapping(uint256 => ProposalCore) private _proposalCores;

  // 状态变量优化
  mapping(uint256 => Proposal) public proposals;
  IERC20 public governanceToken;
  uint256 public proposalCount;
  uint256 public votingDelay; // 提案创建到投票开始的区块数
  uint256 public votingPeriod; // 投票持续的区块数
  uint256 public quorumVotes; // 最小投票数要求

  // 投票委托
  mapping(address => address) public delegates;
  mapping(address => uint256) public delegatedPower;

  // 时间锁
  uint256 public constant GRACE_PERIOD = 7 days;
  uint256 public constant MIN_DELAY = 2 days;
  uint256 public constant MAX_DELAY = 14 days;

  // 时间锁定常量
  uint256 public constant MINIMUM_DELAY = 2 days;
  uint256 public constant MAXIMUM_DELAY = 14 days;

  // 时间锁定映射
  mapping(uint256 => uint256) public proposalTimelocks;

  // 常量优化
  bytes32 private DOMAIN_SEPARATOR;
  bytes32 public constant VOTE_TYPEHASH = keccak256('Vote(uint256 proposalId,bool support)');
  bytes32 public constant DELEGATION_TYPEHASH = keccak256('Delegation(address delegatee)');

  // 事件优化 - 添加更多索引
  event ProposalCreated(
    uint256 indexed proposalId,
    address indexed proposer,
    address[] targets,
    uint256[] values,
    bytes[] calldatas,
    uint256 startBlock,
    uint256 endBlock,
    string description
  );
  event VoteCast(
    address indexed voter,
    uint256 indexed proposalId,
    bool indexed support,
    uint256 weight,
    string reason
  );
  event ProposalExecuted(uint256 indexed proposalId, uint256 timestamp);
  event ProposalCanceled(uint256 indexed proposalId);
  event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
  event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
  event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
  event ProposalEmergencyCanceled(uint256 indexed proposalId, address indexed canceler);
  event ProposalQueued(uint256 indexed proposalId, uint256 eta);

  // 添加 Strategy 合约的引用
  IStrategy public strategy;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _token,
    address _strategy,
    uint256 _votingDelay,
    uint256 _votingPeriod,
    uint256 _quorumVotes
  ) external initializer {
    __EIP712_init('DAOGovernance', '1');
    __ReentrancyGuard_init();
    __Pausable_init();
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();
    __RoleControl_init();

    if (_token == address(0) || _strategy == address(0)) revert ZeroAddress();
    governanceToken = IERC20(_token);
    strategy = IStrategy(_strategy); // 初始化 strategy
    votingDelay = _votingDelay;
    votingPeriod = _votingPeriod;
    quorumVotes = _quorumVotes;
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(Role.SUPER_ADMIN) {}

  // 内部函数：处理提案创建的核心逻辑
  function _createProposal(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) internal whenNotPaused returns (uint256) {
    if (targets.length == 0) revert InvalidProposal('Empty proposal');
    if (targets.length != values.length || targets.length != calldatas.length)
      revert InvalidProposal('Array length mismatch');

    uint256 proposerVotes = getVotes(msg.sender);
    // 提案者需要持有至少10%的治理代币
    if (proposerVotes < quorumVotes / 10) revert NotEnoughVotingPower(quorumVotes / 10, proposerVotes);

    proposalCount++;
    Proposal storage proposal = proposals[proposalCount];
    proposal.proposer = msg.sender;
    proposal.targets = targets;
    proposal.values = values;
    proposal.calldatas = calldatas;
    proposal.startBlock = block.number + votingDelay;
    proposal.endBlock = proposal.startBlock + votingPeriod;
    proposal.eta = block.timestamp + MIN_DELAY;
    proposal.description = description;

    emit ProposalCreated(
      proposalCount,
      msg.sender,
      targets,
      values,
      calldatas,
      proposal.startBlock,
      proposal.endBlock,
      description
    );

    return proposalCount;
  }

  function propose(
    address[] calldata targets,
    uint256[] calldata values,
    bytes[] calldata calldatas,
    string calldata description
  ) external whenNotPaused returns (uint256) {
    return _createProposal(targets, values, calldatas, description);
  }

  function castVote(uint256 proposalId, bool support) external {
    _castVote(msg.sender, proposalId, support, '');
  }

  // 优化批量投票
  function castVoteBySigBatch(
    uint256[] calldata proposalIds,
    bool[] calldata supportValues,
    uint8[] calldata v,
    bytes32[] calldata r,
    bytes32[] calldata s
  ) external whenNotPaused nonReentrant {
    uint256 length = proposalIds.length;
    if (length == 0) revert InvalidProposal('Empty batch');
    if (length != supportValues.length || length != v.length || length != r.length || length != s.length)
      revert InvalidProposal('Array length mismatch');
    if (length > 100) revert InvalidProposal('Batch too large');

    bytes32 domainSeparator = DOMAIN_SEPARATOR;
    for (uint256 i = 0; i < length; ) {
      bytes32 structHash = keccak256(abi.encode(VOTE_TYPEHASH, proposalIds[i], supportValues[i]));
      bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
      address signatory = ECDSA.recover(digest, v[i], r[i], s[i]);

      _castVote(signatory, proposalIds[i], supportValues[i], '');

      unchecked {
        ++i;
      }
    }
  }

  // 提案执行
  function execute(uint256 proposalId) external payable onlyRole(Role.OPERATOR) nonReentrant {
    ProposalState currentState = state(proposalId);
    if (currentState != ProposalState.Succeeded) revert InvalidProposal('Proposal not in succeeded state');

    Proposal storage proposal = proposals[proposalId];

    // 检查是否达到法定票数
    if (proposal.forVotes < quorumVotes) revert QuorumNotReached(proposal.forVotes, quorumVotes);

    // 检查是否获得多数支持
    if (proposal.forVotes <= proposal.againstVotes) revert ProposalNotPassed(proposal.forVotes, proposal.againstVotes);

    // 检查目标合约地址
    for (uint i = 0; i < proposal.targets.length; i++) {
      if (proposal.targets[i] == address(0)) revert ZeroAddress();
      if (proposal.targets[i] == address(this)) revert InvalidTarget();
      // 检查目标是否为合约
      if (proposal.targets[i].code.length == 0) revert NotAContract(proposal.targets[i]);
    }

    // 检查调用数据
    if (proposal.targets.length != proposal.values.length || proposal.targets.length != proposal.calldatas.length) {
      revert InvalidArrayLength();
    }

    // 重入保护
    if (proposal.executed) revert AlreadyExecuted();
    proposal.executed = true;

    _executeTransaction(proposal.targets, proposal.values, proposal.calldatas);

    emit ProposalExecuted(proposalId, block.timestamp);
  }

  // 取消提案
  function cancelProposal(uint256 proposalId) external onlyRole(Role.SUPER_ADMIN) {
    Proposal storage proposal = proposals[proposalId];
    if (msg.sender != proposal.proposer) revert InvalidProposal('Not proposer');
    if (proposal.executed) revert ProposalAlreadyExecuted(proposalId);
    if (block.number > proposal.startBlock) revert VotingClosed(block.number, proposal.startBlock);

    proposal.canceled = true;
    emit ProposalCanceled(proposalId);
  }

  // 优化投票权重计算
  function getVotes(address account) public view returns (uint256) {
    // 如果该账户已委托给其他人，返回0
    if (delegates[account] != address(0)) {
      return 0;
    }

    uint256 ownBalance = governanceToken.balanceOf(account);
    uint256 delegatedAmount = delegatedPower[account];

    // 如果 delegatedAmount > (type(uint256).max - ownBalance)
    // 意味着 delegatedAmount + ownBalance 必然会超过 type(uint256).max
    if (delegatedAmount > type(uint256).max - ownBalance) {
      revert ArithmeticOverflow(ownBalance, delegatedAmount);
    }

    return ownBalance + delegatedAmount;
  }

  function delegate(address delegatee) external whenNotPaused {
    // 防止自我委托
    if (delegatee == msg.sender) revert InvalidDelegation('Cannot delegate to self');

    // 防止循环委托
    address currentDelegate = delegates[msg.sender];
    if (delegates[delegatee] != address(0)) revert InvalidDelegation('Delegatee has delegated their votes');

    uint256 votingPower = governanceToken.balanceOf(msg.sender);

    // 检查余额
    if (votingPower == 0) revert NotEnoughVotingPower(1, 0);

    // 先减后加，防止重入
    if (currentDelegate != address(0)) {
      delegatedPower[currentDelegate] -= votingPower;
    }

    if (delegatee != address(0)) {
      delegatedPower[delegatee] += votingPower;
    }

    delegates[msg.sender] = delegatee;

    emit DelegateChanged(msg.sender, currentDelegate, delegatee);
  }

  function delegateBySig(address delegatee, uint8 v, bytes32 r, bytes32 s) external {
    bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee));
    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', DOMAIN_SEPARATOR, structHash));
    address signatory = ECDSA.recover(digest, v, r, s);

    // Delegate votes
    address currentDelegate = delegates[signatory];
    uint256 votingPower = governanceToken.balanceOf(signatory);

    if (currentDelegate != address(0)) {
      delegatedPower[currentDelegate] -= votingPower;
    }

    if (delegatee != address(0)) {
      delegatedPower[delegatee] += votingPower;
    }

    delegates[signatory] = delegatee;

    emit DelegateChanged(signatory, currentDelegate, delegatee);
  }

  function _castVote(address voter, uint256 proposalId, bool support, string memory reason) internal {
    Proposal storage proposal = proposals[proposalId];

    // 检查是否已投票
    if (proposal.hasVoted[voter]) revert AlreadyVoted(voter, proposalId);

    // 检查投票时间
    if (block.number <= proposal.startBlock) revert VotingClosed(block.number, proposal.startBlock);
    if (block.number >= proposal.endBlock) revert VotingClosed(block.number, proposal.endBlock);

    // 获取实际的投票者（如果已委托，则是被委托人）
    address actualVoter = delegates[voter] != address(0) ? delegates[voter] : voter;

    // 获取投票权重
    uint256 weight = getVotes(actualVoter);
    if (weight == 0) revert NotEnoughVotingPower(1, 0);

    // 记录投票
    proposal.hasVoted[voter] = true;
    if (support) {
      proposal.forVotes += weight;
    } else {
      proposal.againstVotes += weight;
    }

    emit VoteCast(voter, proposalId, support, weight, reason);
  }

  function getProposal(
    uint256 proposalId
  )
    external
    view
    returns (
      address proposer,
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      uint256 startBlock,
      uint256 endBlock,
      uint256 forVotes,
      uint256 againstVotes,
      bool executed
    )
  {
    Proposal storage proposal = proposals[proposalId];
    return (
      proposal.proposer,
      proposal.targets,
      proposal.values,
      proposal.calldatas,
      proposal.startBlock,
      proposal.endBlock,
      proposal.forVotes,
      proposal.againstVotes,
      proposal.executed
    );
  }

  function getProposalState(uint256 proposalId) public view returns (ProposalState) {
    Proposal storage proposal = proposals[proposalId];

    if (proposal.executed) return ProposalState.Executed;
    if (proposal.canceled) return ProposalState.Canceled;
    if (block.number <= proposal.startBlock) return ProposalState.Pending;
    if (block.number <= proposal.endBlock) return ProposalState.Active;
    if (_quorumReached(proposalId) && _proposalSucceeded(proposalId)) return ProposalState.Succeeded;
    return ProposalState.Defeated;
  }

  function _quorumReached(uint256 proposalId) internal view returns (bool) {
    return proposals[proposalId].forVotes >= quorumVotes;
  }

  function _proposalSucceeded(uint256 proposalId) internal view returns (bool) {
    return proposals[proposalId].forVotes > proposals[proposalId].againstVotes;
  }

  function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
    return proposals[proposalId].hasVoted[voter];
  }

  // 紧急取消功能
  function emergencyCancelProposal(uint256 proposalId) external onlyRole(Role.SUPER_ADMIN) whenNotPaused {
    Proposal storage proposal = proposals[proposalId];
    if (proposal.executed) revert ProposalAlreadyExecuted(proposalId);

    proposal.canceled = true;
    emit ProposalEmergencyCanceled(proposalId, msg.sender);
  }

  // 提案阈值调整功能
  function setProposalThreshold(uint256 newThreshold) external onlyRole(Role.SUPER_ADMIN) whenNotPaused {
    if (newThreshold == 0) revert InvalidProposal('Zero threshold');
    emit ProposalThresholdSet(quorumVotes / 10, newThreshold);
    quorumVotes = newThreshold * 10;
  }

  function queue(uint256 proposalId) external onlyRole(Role.OPERATOR) {
    ProposalState status = getProposalState(proposalId);
    if (status != ProposalState.Succeeded) revert InvalidProposal('Proposal not succeeded');

    Proposal storage proposal = proposals[proposalId];

    // 检查是否已经在队列中
    if (proposal.eta != 0) revert AlreadyQueued();

    // 设置执行时间
    uint256 eta = block.timestamp + MINIMUM_DELAY;
    if (eta > block.timestamp + MAXIMUM_DELAY) revert DelayTooLong();

    proposal.eta = eta;
    proposalTimelocks[proposalId] = eta;

    emit ProposalQueued(proposalId, eta);
  }

  function _executeTransaction(address[] memory targets, uint256[] memory values, bytes[] memory calldatas) internal {
    string memory errorMessage = string(abi.encodePacked('Governor: call reverted without message'));

    for (uint256 i = 0; i < targets.length; ) {
      (bool success, bytes memory returndata) = targets[i].call{ value: values[i] }(calldatas[i]);
      if (!success) {
        if (returndata.length > 0) {
          assembly {
            let returndata_size := mload(returndata)
            revert(add(32, returndata), returndata_size)
          }
        } else {
          revert ExecutionFailed(errorMessage);
        }
      }
      unchecked {
        ++i;
      }
    }
  }

  function state(uint256 proposalId) public view returns (ProposalState) {
    if (proposalId > proposalCount) revert ProposalNotExists(proposalId);

    Proposal storage proposal = proposals[proposalId];

    if (proposal.canceled) {
      return ProposalState.Canceled;
    }

    if (proposal.executed) {
      return ProposalState.Executed;
    }

    if (block.number <= proposal.startBlock) {
      return ProposalState.Pending;
    }

    if (block.number <= proposal.endBlock) {
      return ProposalState.Active;
    }

    if (!_quorumReached(proposalId)) {
      return ProposalState.Defeated;
    }

    if (!_proposalSucceeded(proposalId)) {
      return ProposalState.Defeated;
    }

    if (proposal.eta == 0) {
      return ProposalState.Succeeded;
    }

    if (block.timestamp >= proposal.eta && block.timestamp <= proposal.eta + GRACE_PERIOD) {
      return ProposalState.Queued;
    }

    return ProposalState.Expired;
  }

  function proposeStrategyUpdate(
    address token,
    uint256 targetPercentage,
    uint256 rebalanceThreshold,
    address swapPath
  ) external whenNotPaused returns (uint256) {
    // 验证提案者的投票权
    uint256 proposerVotes = getVotes(msg.sender);
    if (proposerVotes < quorumVotes / 10) {
      revert NotEnoughVotingPower(quorumVotes / 10, proposerVotes);
    }

    bytes memory callData = abi.encodeWithSignature(
      'updateStrategy(address,uint256,uint256,address)',
      token,
      targetPercentage,
      rebalanceThreshold,
      swapPath
    );

    address[] memory targets = new address[](1);
    targets[0] = address(strategy);

    uint256[] memory values = new uint256[](1);
    values[0] = 0;

    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = callData;

    return _createProposal(targets, values, calldatas, 'Update investment strategy');
  }

  function proposeBatchStrategyUpdate(
    address[] calldata tokens,
    uint256[] calldata targetPercentages,
    uint256[] calldata rebalanceThresholds,
    address[] calldata swapPaths
  ) external whenNotPaused returns (uint256) {
    // 验证提案者的投票权
    uint256 proposerVotes = getVotes(msg.sender);
    if (proposerVotes < quorumVotes / 10) {
      revert NotEnoughVotingPower(quorumVotes / 10, proposerVotes);
    }

    bytes memory callData = abi.encodeWithSignature(
      'updateStrategies(address[],uint256[],uint256[],address[])',
      tokens,
      targetPercentages,
      rebalanceThresholds,
      swapPaths
    );

    address[] memory targets = new address[](1);
    targets[0] = address(strategy);

    uint256[] memory values = new uint256[](1);
    values[0] = 0;

    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = callData;

    return _createProposal(targets, values, calldatas, 'Batch update investment strategies');
  }

  // 添加更新 strategy 地址的函数
  function setStrategy(address _strategy) external onlyRole(Role.SUPER_ADMIN) {
    require(_strategy != address(0), 'Zero address');
    strategy = IStrategy(_strategy);
  }
}
