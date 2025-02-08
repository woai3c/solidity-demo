// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { EIP712 } from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { ECDSA } from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';
import { AccessControl } from '@openzeppelin/contracts/access/AccessControl.sol';

contract Governance is EIP712, ReentrancyGuard, Pausable, AccessControl {
  using SafeERC20 for IERC20;

  // Move role definitions to the top of contract
  bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

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

  // 提案状态枚举 - 添加新状态
  enum ProposalState {
    Pending, // 等待投票开始
    Active, // 投票进行中
    Defeated, // 投票失败
    Succeeded, // 投票成功
    Executed, // 已执行
    Expired,
    Canceled
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
    mapping(address => bool) hasVoted;
  }

  // 状态变量优化
  mapping(uint256 => Proposal) public proposals;
  IERC20 public immutable governanceToken;
  uint256 public proposalCount;
  uint256 public immutable votingDelay; // 提案创建到投票开始的区块数
  uint256 public immutable votingPeriod; // 投票持续的区块数
  uint256 public quorumVotes; // 最小投票数要求

  // 投票委托
  mapping(address => address) public delegates;
  mapping(address => uint256) public delegatedPower;

  // 时间锁
  uint256 public constant GRACE_PERIOD = 7 days;
  uint256 public constant MIN_DELAY = 2 days;
  uint256 public constant MAX_DELAY = 14 days;

  // 常量优化
  bytes32 private immutable DOMAIN_SEPARATOR;
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

  constructor(
    address _token,
    uint256 _votingDelay,
    uint256 _votingPeriod,
    uint256 _quorumVotes
  ) EIP712('DAOGovernance', '1') {
    governanceToken = IERC20(_token);
    votingDelay = _votingDelay;
    votingPeriod = _votingPeriod;
    quorumVotes = _quorumVotes;
    DOMAIN_SEPARATOR = _domainSeparatorV4();

    // 使用 _grantRole 替代 _setupRole
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(ADMIN_ROLE, msg.sender);

    // Grant admin role the ability to grant other roles
    _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
  }

  // 优化提案创建
  function propose(
    address[] calldata targets,
    uint256[] calldata values,
    bytes[] calldata calldatas,
    string calldata description
  ) external whenNotPaused returns (uint256) {
    if (targets.length == 0) revert InvalidProposal('Empty proposal');
    if (targets.length != values.length || targets.length != calldatas.length)
      revert InvalidProposal('Array length mismatch');

    uint256 proposerVotes = getVotes(msg.sender);
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
  function execute(uint256 proposalId) external nonReentrant whenNotPaused {
    Proposal storage proposal = proposals[proposalId];
    if (proposal.executed) revert ProposalAlreadyExecuted(proposalId);
    if (proposal.canceled) revert ProposalExpired(proposalId);
    if (block.timestamp < proposal.eta) revert VotingClosed(block.timestamp, proposal.eta);
    if (block.timestamp > proposal.eta + GRACE_PERIOD) revert ProposalExpired(proposalId);

    ProposalState state = getProposalState(proposalId);
    if (state != ProposalState.Succeeded) revert QuorumNotReached(0, 0);

    proposal.executed = true;

    for (uint256 i = 0; i < proposal.targets.length; ) {
      (bool success, bytes memory returndata) = proposal.targets[i].call{ value: proposal.values[i] }(
        proposal.calldatas[i]
      );
      if (!success) {
        if (returndata.length > 0) {
          assembly {
            let returndata_size := mload(returndata)
            revert(add(32, returndata), returndata_size)
          }
        } else {
          revert ExecutionFailed('Call reverted');
        }
      }
      unchecked {
        ++i;
      }
    }

    emit ProposalExecuted(proposalId, block.timestamp);
  }

  // 取消提案
  function cancelProposal(uint256 proposalId) external {
    Proposal storage proposal = proposals[proposalId];
    if (msg.sender != proposal.proposer) revert InvalidProposal('Not proposer');
    if (proposal.executed) revert ProposalAlreadyExecuted(proposalId);
    if (block.number > proposal.startBlock) revert VotingClosed(block.number, proposal.startBlock);

    proposal.canceled = true;
    emit ProposalCanceled(proposalId);
  }

  // 优化投票权重计算
  function getVotes(address account) public view returns (uint256) {
    uint256 ownVotes = governanceToken.balanceOf(account);
    uint256 delegatedVotes = delegatedPower[account];
    return ownVotes + delegatedVotes;
  }

  function delegate(address delegatee) external whenNotPaused {
    address currentDelegate = delegates[msg.sender];
    uint256 votingPower = governanceToken.balanceOf(msg.sender);

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
    if (proposal.hasVoted[voter]) revert AlreadyVoted(voter, proposalId);
    if (block.number <= proposal.startBlock) revert VotingClosed(block.number, proposal.startBlock);
    if (block.number >= proposal.endBlock) revert VotingClosed(block.number, proposal.endBlock);

    proposal.hasVoted[voter] = true;

    uint256 weight = governanceToken.balanceOf(voter);
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
    return proposals[proposalId].forVotes + proposals[proposalId].againstVotes >= quorumVotes;
  }

  function _proposalSucceeded(uint256 proposalId) internal view returns (bool) {
    return proposals[proposalId].forVotes > proposals[proposalId].againstVotes;
  }

  function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
    return proposals[proposalId].hasVoted[voter];
  }

  // 紧急取消功能
  function emergencyCancelProposal(uint256 proposalId) external onlyRole(ADMIN_ROLE) whenNotPaused {
    Proposal storage proposal = proposals[proposalId];
    if (proposal.executed) revert ProposalAlreadyExecuted(proposalId);

    proposal.canceled = true;
    emit ProposalEmergencyCanceled(proposalId, msg.sender);
  }

  // 提案阈值调整功能
  function setProposalThreshold(uint256 newThreshold) external onlyRole(ADMIN_ROLE) whenNotPaused {
    if (newThreshold == 0) revert InvalidProposal('Zero threshold');
    emit ProposalThresholdSet(quorumVotes / 10, newThreshold);
    quorumVotes = newThreshold * 10;
  }
}
