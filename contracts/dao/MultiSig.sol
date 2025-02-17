// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';
import { EnumerableSet } from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**
 * @title MultiSig
 * @dev Enhanced version of the multi-signature wallet with additional security features
 */
contract MultiSig is ReentrancyGuard, Pausable {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;

  // 自定义错误
  error InvalidOwner();
  error InvalidThreshold();
  error OwnerNotFound();
  error OwnerAlreadyExists();
  error InvalidSignaturesCount();
  error AlreadyExecuted();
  error ExecutionFailed();
  error NotEnoughSignatures();
  error AlreadyConfirmed();
  error NotConfirmed();
  error InvalidDelay();
  error TransactionNotQueued();
  error TimelockNotReady();
  error InvalidNonce();
  error CallFailed();
  error InvalidInput();
  error InvalidGasLimit(uint256 provided, uint256 maximum);
  error TransactionExpired(uint256 deadline);
  error UrgentVotesFailed(uint256 current, uint256 required);
  error NotUrgent();
  error InvalidRole();

  // 角色枚举
  enum Role {
    BASIC,
    ADMIN,
    SUPER_ADMIN
  }

  // 交易结构
  struct Transaction {
    address to;
    uint256 value;
    bytes data;
    bool executed;
    uint256 numConfirmations;
    uint256 queuedTime;
    bytes32 txHash;
    uint256 gasLimit;
    bool isUrgent;
    uint256 urgentVotes;
  }

  // 常量
  uint256 public constant MIN_DELAY = 1 hours;
  uint256 public constant MAX_DELAY = 30 days;
  uint256 public constant GRACE_PERIOD = 14 days;
  uint256 public constant MAX_GAS = 3000000;
  uint256 public constant MIN_EXECUTION_WINDOW = 1 hours;

  // 状态变量
  uint256 public immutable CHAIN_ID;
  uint256 public threshold;
  uint256 public delay;
  uint256 public nonce;
  EnumerableSet.AddressSet private owners;
  mapping(uint256 => Transaction) public transactions;
  mapping(uint256 => mapping(address => bool)) public isConfirmed;
  mapping(bytes32 => bool) public queuedTransactions;
  mapping(address => Role) public ownerRoles;
  uint256 public transactionCount;
  uint256 public immutable deployTime;
  mapping(uint256 => mapping(address => bool)) public urgentVotings;
  mapping(address => uint256) public lastOperationTime;

  // 事件 (添加更多信息)
  event OwnerAdded(address indexed owner, Role role);
  event OwnerRemoved(address indexed owner);
  event ThresholdChanged(uint256 threshold);
  event DelayChanged(uint256 delay);
  event TransactionSubmitted(
    uint256 indexed txId,
    address indexed to,
    uint256 value,
    bytes data,
    bytes32 txHash,
    uint256 gasLimit
  );
  event TransactionQueued(uint256 indexed txId, uint256 executionTime);
  event TransactionConfirmed(uint256 indexed txId, address indexed owner);
  event TransactionRevoked(uint256 indexed txId, address indexed owner);
  event TransactionExecuted(uint256 indexed txId, address indexed to, uint256 value, bytes data, uint256 timestamp);
  event TransactionCancelled(uint256 indexed txId);
  event EtherReceived(address indexed sender, uint256 amount);
  event TokensReceived(address indexed token, address indexed recipient, uint256 amount);
  event TokenApproved(address indexed token, address indexed spender, uint256 amount);
  event UrgentTransactionVoted(uint256 indexed txId, address indexed owner, uint256 votes);

  constructor(address[] memory _owners, uint256 _threshold, uint256 _delay) {
    if (_owners.length == 0) revert InvalidOwner();
    if (_threshold == 0 || _threshold > _owners.length) revert InvalidThreshold();
    if (_delay < MIN_DELAY || _delay > MAX_DELAY) revert InvalidDelay();

    CHAIN_ID = block.chainid;

    for (uint256 i = 0; i < _owners.length; ) {
      address owner = _owners[i];
      if (owner == address(0)) revert InvalidOwner();
      if (owners.contains(owner)) revert OwnerAlreadyExists();
      owners.add(owner);
      ownerRoles[owner] = i == 0 ? Role.SUPER_ADMIN : Role.BASIC;
      unchecked {
        ++i;
      }
    }

    threshold = _threshold;
    delay = _delay;
    deployTime = block.timestamp;
  }

  // 修饰器
  modifier onlyOwner() {
    if (!owners.contains(msg.sender)) revert InvalidOwner();
    _;
  }

  modifier onlyRole(Role role) {
    if (ownerRoles[msg.sender] < role) revert InvalidRole();
    _;
  }

  modifier txExists(uint256 _txId) {
    if (_txId >= transactionCount) revert InvalidSignaturesCount();
    _;
  }

  modifier notExecuted(uint256 _txId) {
    if (transactions[_txId].executed) revert AlreadyExecuted();
    _;
  }

  modifier notConfirmed(uint256 _txId) {
    if (isConfirmed[_txId][msg.sender]) revert AlreadyConfirmed();
    _;
  }

  // 核心功能
  function submitTransaction(
    address _to,
    uint256 _value,
    bytes calldata _data,
    uint256 _gasLimit
  ) external onlyOwner whenNotPaused returns (uint256 txId) {
    if (_gasLimit > MAX_GAS) revert InvalidGasLimit(_gasLimit, MAX_GAS);

    txId = transactionCount;
    bytes32 txHash = keccak256(abi.encode(_to, _value, _data, nonce++, CHAIN_ID));

    transactions[txId] = Transaction({
      to: _to,
      value: _value,
      data: _data,
      executed: false,
      numConfirmations: 0,
      queuedTime: 0,
      txHash: txHash,
      gasLimit: _gasLimit,
      isUrgent: false,
      urgentVotes: 0
    });

    transactionCount++;

    emit TransactionSubmitted(txId, _to, _value, _data, txHash, _gasLimit);
  }

  function queueTransaction(uint256 _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
    Transaction storage transaction = transactions[_txId];
    transaction.queuedTime = block.timestamp + delay;
    queuedTransactions[transaction.txHash] = true;

    emit TransactionQueued(_txId, transaction.queuedTime);
  }

  function confirmTransaction(
    uint256 _txId
  ) external onlyOwner txExists(_txId) notExecuted(_txId) notConfirmed(_txId) whenNotPaused {
    Transaction storage transaction = transactions[_txId];
    transaction.numConfirmations += 1;
    isConfirmed[_txId][msg.sender] = true;

    // 自动执行
    if (
      transaction.numConfirmations >= threshold && !transaction.executed && block.timestamp >= transaction.queuedTime
    ) {
      executeTransaction(_txId);
    }

    emit TransactionConfirmed(_txId, msg.sender);
  }

  function executeTransaction(
    uint256 _txId
  ) public nonReentrant onlyOwner txExists(_txId) notExecuted(_txId) whenNotPaused {
    Transaction storage transaction = transactions[_txId];

    if (!queuedTransactions[transaction.txHash]) revert TransactionNotQueued();
    if (transaction.numConfirmations < threshold) revert NotEnoughSignatures();
    if (block.timestamp < transaction.queuedTime) revert TimelockNotReady();
    if (block.timestamp > transaction.queuedTime + GRACE_PERIOD || transaction.queuedTime == 0)
      revert TimelockNotReady();

    transaction.executed = true;

    // 执行交易
    if (transaction.data.length > 0) {
      (bool success, ) = transaction.to.call{ value: transaction.value, gas: transaction.gasLimit }(transaction.data);
      if (!success) revert ExecutionFailed();
    } else {
      (bool success, ) = transaction.to.call{ value: transaction.value, gas: transaction.gasLimit }('');
      if (!success) revert ExecutionFailed();
    }

    lastOperationTime[msg.sender] = block.timestamp;

    emit TransactionExecuted(_txId, transaction.to, transaction.value, transaction.data, block.timestamp);
  }

  // 取消交易功能
  function cancelTransaction(uint256 _txId) external onlyOwner txExists(_txId) notExecuted(_txId) whenNotPaused {
    Transaction storage transaction = transactions[_txId];
    if (transaction.queuedTime == 0) revert TransactionNotQueued();

    delete queuedTransactions[transaction.txHash];
    transaction.queuedTime = 0;
    emit TransactionCancelled(_txId);
  }

  // 批量执行交易
  function executeBatchTransactions(uint256[] calldata _txIds) external nonReentrant onlyOwner whenNotPaused {
    if (_txIds.length > 10) revert InvalidInput();
    uint256 length = _txIds.length;
    for (uint256 i = 0; i < length; ) {
      executeTransaction(_txIds[i]);
      unchecked {
        ++i;
      }
    }
  }

  // 修改: 紧急执行功能
  function markTransactionUrgent(
    uint256 _txId
  ) external onlyRole(Role.ADMIN) txExists(_txId) notExecuted(_txId) whenNotPaused {
    Transaction storage transaction = transactions[_txId];
    if (urgentVotings[_txId][msg.sender]) revert AlreadyConfirmed();

    if (!transaction.isUrgent) {
      transaction.isUrgent = true;
    }

    urgentVotings[_txId][msg.sender] = true;
    transaction.urgentVotes += 1;

    emit UrgentTransactionVoted(_txId, msg.sender, transaction.urgentVotes);
  }

  // 修改: 紧急执行交易
  function executeUrgentTransaction(
    uint256 _txId
  ) external nonReentrant onlyRole(Role.ADMIN) txExists(_txId) notExecuted(_txId) {
    Transaction storage transaction = transactions[_txId];
    if (!transaction.isUrgent) revert NotUrgent();

    // 修改: 使用实际所有者数量的 2/3 作为条件
    uint256 ownerCount = owners.length();
    uint256 requiredVotes = (ownerCount * 2) / 3; // 需要 2/3 的所有者同意
    if (transaction.urgentVotes < requiredVotes) revert UrgentVotesFailed(transaction.urgentVotes, requiredVotes);

    // 执行交易
    if (transaction.data.length > 0) {
      (bool success, ) = transaction.to.call{ value: transaction.value, gas: transaction.gasLimit }(transaction.data);
      if (!success) revert ExecutionFailed();
    } else {
      (bool success, ) = transaction.to.call{ value: transaction.value, gas: transaction.gasLimit }('');
      if (!success) revert ExecutionFailed();
    }

    transaction.executed = true;

    emit TransactionExecuted(_txId, transaction.to, transaction.value, transaction.data, block.timestamp);
  }

  // 修改: 估算交易 gas
  function estimateTransactionGas(uint256 _txId) external view txExists(_txId) notExecuted(_txId) returns (uint256) {
    Transaction storage transaction = transactions[_txId];

    // 1. 基础 gas 成本
    uint256 gasEstimate = 21000; // 基础交易成本

    // 2. 计算调用数据的 gas 成本
    bytes memory txData = transaction.data;
    if (txData.length > 0) {
      // 计算调用数据的确切 gas 成本
      uint256 nonZeroBytes = 0;
      uint256 zeroBytes = 0;

      for (uint i = 0; i < txData.length; ) {
        if (txData[i] == 0) {
          zeroBytes++;
        } else {
          nonZeroBytes++;
        }
        unchecked {
          ++i;
        }
      }

      // EIP-2028: 非零字节 16 gas，零字节 4 gas
      gasEstimate += (nonZeroBytes * 16 + zeroBytes * 4);
    }

    // 3. 添加合约调用的基础成本
    if (transaction.to.code.length > 0) {
      gasEstimate += 700; // CALL 操作码成本
    }

    // 4. 如果涉及 ETH 转账
    if (transaction.value > 0) {
      gasEstimate += 9000; // CALL with value 成本
    }

    // 5. 添加存储操作成本
    if (transaction.data.length > 0) {
      gasEstimate += 20000; // 预估 SSTORE 操作
    }

    // 6. 添加安全边际 (20%)
    gasEstimate = (gasEstimate * 120) / 100;

    // 7. 确保不超过最大限制
    if (gasEstimate > MAX_GAS) {
      return MAX_GAS;
    }

    // 8. 确保不低于最小合理值
    if (gasEstimate < 21000) {
      return 21000;
    }

    return gasEstimate;
  }

  // 批量查询交易状态
  function getTransactionsStatus(
    uint256[] calldata _txIds
  ) external view returns (bool[] memory executed, uint256[] memory confirmations) {
    uint256 length = _txIds.length;
    executed = new bool[](length);
    confirmations = new uint256[](length);

    for (uint256 i = 0; i < length; ) {
      if (_txIds[i] < transactionCount) {
        Transaction storage transaction = transactions[_txIds[i]];
        executed[i] = transaction.executed;
        confirmations[i] = transaction.numConfirmations;
      }
      unchecked {
        ++i;
      }
    }
  }

  // 转移所有者角色
  function transferOwnerRole(address _from, address _to, Role _role) external onlyRole(Role.SUPER_ADMIN) whenNotPaused {
    if (!owners.contains(_from)) revert OwnerNotFound();
    if (_to == address(0)) revert InvalidOwner();
    if (owners.contains(_to)) revert OwnerAlreadyExists();

    owners.remove(_from);
    owners.add(_to);
    ownerRoles[_to] = _role;
    delete ownerRoles[_from];

    emit OwnerRemoved(_from);
    emit OwnerAdded(_to, _role);
  }

  // 验证交易是否可执行
  function isTransactionExecutable(uint256 _txId) public view returns (bool, string memory) {
    if (_txId >= transactionCount) {
      return (false, 'Transaction does not exist');
    }

    Transaction storage transaction = transactions[_txId];

    if (transaction.executed) {
      return (false, 'Already executed');
    }

    if (transaction.numConfirmations < threshold) {
      return (false, 'Not enough confirmations');
    }

    if (!queuedTransactions[transaction.txHash]) {
      return (false, 'Not queued');
    }

    if (block.timestamp < transaction.queuedTime) {
      return (false, 'Timelock not ready');
    }

    if (block.timestamp > transaction.queuedTime + GRACE_PERIOD) {
      return (false, 'Grace period expired');
    }

    return (true, '');
  }

  // 批量授权代币
  function batchApproveTokens(
    address[] calldata tokens,
    address[] calldata spenders,
    uint256[] calldata amounts
  ) external onlyOwner whenNotPaused {
    if (tokens.length != spenders.length || tokens.length != amounts.length) revert InvalidInput();

    uint256 length = tokens.length;
    for (uint256 i = 0; i < length; ) {
      bool success = IERC20(tokens[i]).approve(spenders[i], amounts[i]);
      if (!success) revert CallFailed();
      emit TokenApproved(tokens[i], spenders[i], amounts[i]);
      unchecked {
        ++i;
      }
    }
  }

  // 紧急提取所有 ETH
  function emergencyEtherWithdraw(address payable _to) external onlyRole(Role.SUPER_ADMIN) {
    uint256 balance = address(this).balance;
    (bool success, ) = _to.call{ value: balance }('');
    if (!success) revert CallFailed();
    emit EtherReceived(_to, balance);
  }

  // 紧急提取所有代币
  function emergencyTokenWithdraw(
    address[] calldata tokens,
    address to,
    uint256[] calldata amounts
  ) external onlyRole(Role.SUPER_ADMIN) {
    uint256 length = tokens.length;
    if (amounts.length != 0 && amounts.length != length) revert InvalidInput();

    for (uint i = 0; i < length; ) {
      uint256 amount = amounts.length == 0 ? IERC20(tokens[i]).balanceOf(address(this)) : amounts[i];

      IERC20(tokens[i]).safeTransfer(to, amount);
      emit TokensReceived(tokens[i], to, amount);

      unchecked {
        ++i;
      }
    }
  }

  function revokeConfirmation(uint256 _txId) external onlyOwner txExists(_txId) notExecuted(_txId) whenNotPaused {
    if (!isConfirmed[_txId][msg.sender]) revert NotConfirmed();

    Transaction storage transaction = transactions[_txId];
    transaction.numConfirmations -= 1;
    isConfirmed[_txId][msg.sender] = false;

    emit TransactionRevoked(_txId, msg.sender);
  }

  // 管理功能
  function addOwner(address _owner) external onlyRole(Role.SUPER_ADMIN) whenNotPaused {
    if (_owner == address(0)) revert InvalidOwner();
    if (owners.contains(_owner)) revert OwnerAlreadyExists();

    owners.add(_owner);
    ownerRoles[_owner] = Role.BASIC;
    emit OwnerAdded(_owner, Role.BASIC);
  }

  function removeOwner(address _owner) external onlyRole(Role.SUPER_ADMIN) whenNotPaused {
    if (!owners.contains(_owner)) revert OwnerNotFound();
    if (owners.length() <= threshold) revert InvalidThreshold();

    owners.remove(_owner);
    emit OwnerRemoved(_owner);
  }

  function changeThreshold(uint256 _threshold) external onlyOwner whenNotPaused {
    if (_threshold == 0 || _threshold > owners.length()) revert InvalidThreshold();

    threshold = _threshold;
    emit ThresholdChanged(_threshold);
  }

  function changeDelay(uint256 _delay) external onlyOwner whenNotPaused {
    if (_delay < MIN_DELAY || _delay > MAX_DELAY) revert InvalidDelay();
    delay = _delay;
    emit DelayChanged(_delay);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  // 查询功能
  function getOwners() external view returns (address[] memory) {
    return owners.values();
  }

  function getTransactionCount() external view returns (uint256) {
    return transactionCount;
  }

  function getTransaction(
    uint256 _txId
  )
    external
    view
    returns (
      address to,
      uint256 value,
      bytes memory data,
      bool executed,
      uint256 numConfirmations,
      uint256 queuedTime,
      bytes32 txHash,
      uint256 gasLimit,
      bool isUrgent,
      uint256 urgentVotes
    )
  {
    Transaction storage transaction = transactions[_txId];
    return (
      transaction.to,
      transaction.value,
      transaction.data,
      transaction.executed,
      transaction.numConfirmations,
      transaction.queuedTime,
      transaction.txHash,
      transaction.gasLimit,
      transaction.isUrgent,
      transaction.urgentVotes
    );
  }

  function executeTokenTransfer(address token, address to, uint256 amount) external onlyOwner whenNotPaused {
    if (token == address(0)) revert InvalidOwner();
    if (to == address(0)) revert InvalidOwner();

    bool success = IERC20(token).transfer(to, amount);
    if (!success) revert CallFailed();

    emit TokensReceived(token, to, amount);
  }

  // 批量转账
  function batchTokenTransfer(
    address[] calldata tokens,
    address[] calldata recipients,
    uint256[] calldata amounts
  ) external onlyOwner whenNotPaused {
    if (tokens.length != recipients.length || tokens.length != amounts.length) revert InvalidInput();

    for (uint i = 0; i < tokens.length; i++) {
      bool success = IERC20(tokens[i]).transfer(recipients[i], amounts[i]);
      if (!success) revert CallFailed();
      emit TokensReceived(tokens[i], recipients[i], amounts[i]);
    }
  }

  // 代币授权功能
  function approveToken(address token, address spender, uint256 amount) external onlyOwner whenNotPaused {
    bool success = IERC20(token).approve(spender, amount);
    if (!success) revert CallFailed();
    emit TokenApproved(token, spender, amount);
  }

  // 安全的代币操作
  function safeTokenTransfer(address token, address to, uint256 amount) external onlyOwner whenNotPaused {
    if (token == address(0) || to == address(0)) revert InvalidInput();
    IERC20(token).safeTransfer(to, amount);
    emit TokensReceived(token, to, amount);
  }

  // 带超时的确认
  function confirmTransactionWithTimeout(
    uint256 _txId,
    uint256 _timeout
  ) external onlyOwner txExists(_txId) notExecuted(_txId) notConfirmed(_txId) {
    if (_timeout < MIN_EXECUTION_WINDOW || _timeout > MAX_DELAY) revert InvalidDelay();
    Transaction storage transaction = transactions[_txId];
    transaction.numConfirmations += 1;
    isConfirmed[_txId][msg.sender] = true;
    transactions[_txId].queuedTime = block.timestamp + _timeout;
    emit TransactionConfirmed(_txId, msg.sender);
  }

  // 交易重放保护
  function isReplayProtected(bytes32 txHash) public view returns (bool) {
    return queuedTransactions[txHash] || keccak256(abi.encode(txHash, CHAIN_ID, address(this))) != bytes32(0);
  }

  // 验证交易链ID
  function validateChainId() public view returns (bool) {
    return block.chainid == CHAIN_ID;
  }

  // 接收函数
  receive() external payable {
    if (msg.value < 0.01 ether) revert InvalidInput();
    emit EtherReceived(msg.sender, msg.value);
  }

  // 回退函数
  fallback() external payable {
    emit EtherReceived(msg.sender, msg.value);
  }
}
