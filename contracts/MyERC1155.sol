// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

// ERC1155 Receiver Interface
interface IERC1155Receiver {
  function onERC1155Received(
    address operator,
    address from,
    uint256 id,
    uint256 value,
    bytes calldata data
  ) external returns (bytes4);

  function onERC1155BatchReceived(
    address operator,
    address from,
    uint256[] calldata ids,
    uint256[] calldata values,
    bytes calldata data
  ) external returns (bytes4);
}

// 定义自定义错误
error SelfApproval();
error ZeroAddress();
error NotAuthorized();
error InsufficientBalance();
error LengthMismatch();
error ReceiverRejected();
error InvalidReceiver();
error InvalidQuantity();
error MaxSupplyExceeded();
error ContractPaused();
error BlacklistedAddress();
error MaxTokenLimitReached();
error MetadataLocked();
error TransferFailed();

contract MyERC1155 is ReentrancyGuard, Ownable {
  using Strings for uint256;

  // 事件定义
  event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
  event TransferBatch(
    address indexed operator,
    address indexed from,
    address indexed to,
    uint256[] ids,
    uint256[] values
  );
  event ApprovalForAll(address indexed account, address indexed operator, bool approved);
  event URI(string value, uint256 indexed id);
  event ContractPausedStateChanged(bool isPaused);
  event BlacklistStateChanged(address indexed account, bool isBlacklisted);
  event WithdrawETH(address indexed to, uint256 amount);
  event WithdrawERC20(address indexed to, address indexed token, uint256 amount);

  // 映射：账户地址 => 代币ID => 余额
  mapping(address => mapping(uint256 => uint256)) private _balances;
  // 映射：账户地址 => 操作者地址 => 是否批准
  mapping(address => mapping(address => bool)) private _operatorApprovals;
  mapping(uint256 => uint256) private _totalSupply;
  mapping(uint256 => uint256) private _maxSupply;
  mapping(address => bool) private _blacklisted;

  // 代币URI
  string private _uri;

  // 添加一个计数器来追踪NFT的ID
  uint256 private _nextTokenId;

  bool private _paused;
  bool private _metadataLocked;
  uint256 private constant MAX_TOKEN_LIMIT = 1_000_000;

  constructor(string memory uri_) Ownable(msg.sender) {
    _uri = uri_;
  }

  // 设置是否批准操作者管理所有代币
  function setApprovalForAll(address operator, bool approved) public {
    if (operator == msg.sender) {
      revert SelfApproval();
    }
    _operatorApprovals[msg.sender][operator] = approved;
    emit ApprovalForAll(msg.sender, operator, approved);
  }

  // 检查是否批准
  function isApprovedForAll(address account, address operator) public view returns (bool) {
    return _operatorApprovals[account][operator];
  }

  // 查询单个代币余额
  function balanceOf(address account, uint256 id) public view returns (uint256) {
    if (account == address(0)) {
      revert ZeroAddress();
    }
    return _balances[account][id];
  }

  // 批量查询代币余额
  function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view returns (uint256[] memory) {
    if (accounts.length != ids.length) {
      revert LengthMismatch();
    }
    uint256[] memory batchBalances = new uint256[](accounts.length);

    for (uint256 i = 0; i < accounts.length; ++i) {
      batchBalances[i] = balanceOf(accounts[i], ids[i]);
    }

    return batchBalances;
  }

  // 安全转移单个代币
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public whenNotPaused notBlacklisted(from) notBlacklisted(to) nonReentrant {
    if (from != msg.sender && !isApprovedForAll(from, msg.sender)) {
      revert NotAuthorized();
    }
    if (to == address(0)) {
      revert ZeroAddress();
    }
    if (_balances[from][id] < amount) {
      revert InsufficientBalance();
    }

    _balances[from][id] -= amount;
    _balances[to][id] += amount;

    emit TransferSingle(msg.sender, from, to, id, amount);

    _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
  }

  // 批量安全转移代币
  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) public whenNotPaused notBlacklisted(from) notBlacklisted(to) nonReentrant {
    if (from != msg.sender && !isApprovedForAll(from, msg.sender)) {
      revert NotAuthorized();
    }
    if (to == address(0)) {
      revert ZeroAddress();
    }
    if (ids.length != amounts.length) {
      revert LengthMismatch();
    }

    for (uint256 i = 0; i < ids.length; ++i) {
      uint256 id = ids[i];
      uint256 amount = amounts[i];

      if (_balances[from][id] < amount) {
        revert InsufficientBalance();
      }

      _balances[from][id] -= amount;
      _balances[to][id] += amount;
    }

    emit TransferBatch(msg.sender, from, to, ids, amounts);

    _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
  }

  // 铸造代币（需要在实际使用时添加访问控制）
  function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal {
    if (to == address(0)) {
      revert ZeroAddress();
    }

    _balances[to][id] += amount;
    emit TransferSingle(msg.sender, address(0), to, id, amount);

    _doSafeTransferAcceptanceCheck(msg.sender, address(0), to, id, amount, data);
  }

  // 检查接收者是否正确实现了接收接口
  function _doSafeTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) private {
    if (to.code.length > 0) {
      try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
        if (response != IERC1155Receiver.onERC1155Received.selector) {
          revert ReceiverRejected();
        }
      } catch {
        revert InvalidReceiver();
      }
    }
  }

  // 批量转移的接收检查
  function _doSafeBatchTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) private {
    if (to.code.length > 0) {
      try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
        if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
          revert ReceiverRejected();
        }
      } catch {
        revert InvalidReceiver();
      }
    }
  }

  // 铸造同质化代币
  function mintFT(address to, uint256 id, uint256 amount, bytes memory data) public {
    if (amount == 0) revert InvalidQuantity();
    if (_maxSupply[id] != 0) {
      if (_totalSupply[id] + amount > _maxSupply[id]) revert MaxSupplyExceeded();
    }
    _totalSupply[id] += amount;
    _mint(to, id, amount, data);
  }

  // 铸造非同质化代币
  function mintNFT(address to, bytes memory data) public returns (uint256) {
    if (_nextTokenId >= MAX_TOKEN_LIMIT) revert MaxTokenLimitReached();
    uint256 tokenId = _nextTokenId++;
    _totalSupply[tokenId] += 1;
    _mint(to, tokenId, 1, data);
    return tokenId;
  }

  // 批量铸造NFT
  function mintBatchNFT(address to, uint256 quantity, bytes memory data) public returns (uint256[] memory) {
    uint256[] memory tokenIds = new uint256[](quantity);

    for (uint256 i = 0; i < quantity; i++) {
      tokenIds[i] = _nextTokenId++;
      _mint(to, tokenIds[i], 1, data);
    }

    return tokenIds;
  }

  // 批量铸造FT代币
  function mintBatchFT(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public {
    if (ids.length != amounts.length) revert LengthMismatch();

    for (uint256 i = 0; i < ids.length; ++i) {
      if (amounts[i] == 0) revert InvalidQuantity();
      if (_maxSupply[ids[i]] != 0) {
        if (_totalSupply[ids[i]] + amounts[i] > _maxSupply[ids[i]]) revert MaxSupplyExceeded();
      }
      _totalSupply[ids[i]] += amounts[i];
      _mint(to, ids[i], amounts[i], data);
    }
  }

  // 销毁代币功能
  function burn(address from, uint256 id, uint256 amount) public {
    if (from != msg.sender && !isApprovedForAll(from, msg.sender)) revert NotAuthorized();
    if (_balances[from][id] < amount) revert InsufficientBalance();

    _balances[from][id] -= amount;
    _totalSupply[id] -= amount;

    emit TransferSingle(msg.sender, from, address(0), id, amount);
  }

  // Modifiers
  modifier whenNotPaused() {
    if (_paused) revert ContractPaused();
    _;
  }

  modifier notBlacklisted(address account) {
    if (_blacklisted[account]) revert BlacklistedAddress();
    _;
  }

  // Admin functions
  function setPaused(bool state) external onlyOwner {
    _paused = state;
    emit ContractPausedStateChanged(state);
  }

  function setBlacklist(address account, bool state) external onlyOwner {
    _blacklisted[account] = state;
    emit BlacklistStateChanged(account, state);
  }

  function setMaxSupply(uint256 id, uint256 newMaxSupply) external onlyOwner {
    _maxSupply[id] = newMaxSupply;
  }

  function setURI(string memory newuri) external onlyOwner {
    if (_metadataLocked) revert MetadataLocked();
    _uri = newuri;
  }

  function lockMetadata() external onlyOwner {
    _metadataLocked = true;
  }

  // View functions
  function uri(uint256 id) public view returns (string memory) {
    return string(abi.encodePacked(_uri, id.toString()));
  }

  function totalSupply(uint256 id) public view returns (uint256) {
    return _totalSupply[id];
  }

  function maxSupply(uint256 id) public view returns (uint256) {
    return _maxSupply[id];
  }

  // Emergency functions
  function withdraw() external onlyOwner nonReentrant {
    uint256 balance = address(this).balance;
    if (balance == 0) revert InsufficientBalance();

    (bool success, ) = msg.sender.call{ value: balance }('');
    if (!success) revert TransferFailed();

    emit WithdrawETH(msg.sender, balance);
  }

  function withdrawERC20(address token) external onlyOwner nonReentrant {
    uint256 balance = IERC20(token).balanceOf(address(this));
    if (balance == 0) revert InsufficientBalance();

    if (!IERC20(token).transfer(msg.sender, balance)) revert TransferFailed();

    emit WithdrawERC20(msg.sender, token, balance);
  }
}
