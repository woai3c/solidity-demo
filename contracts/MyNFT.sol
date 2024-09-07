// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';

interface IERC165 {
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 {
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
  event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

  function balanceOf(address owner) external view returns (uint256 balance);
  function ownerOf(uint256 tokenId) external view returns (address owner);
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;
  function safeTransferFrom(address from, address to, uint256 tokenId) external;
  function transferFrom(address from, address to, uint256 tokenId) external;
  function approve(address to, uint256 tokenId) external;
  function setApprovalForAll(address operator, bool approved) external;
  function getApproved(uint256 tokenId) external view returns (address operator);
  function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC721Metadata {
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function tokenURI(uint256 tokenId) external view returns (string memory);
}

interface IERC721Enumerable {
  function totalSupply() external view returns (uint256);
  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);
  function tokenByIndex(uint256 index) external view returns (uint256);
}

interface IERC721Receiver {
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external returns (bytes4);
}

contract MyNFT is IERC721, IERC721Metadata, IERC721Enumerable, IERC165, Ownable {
  string private _name;
  string private _symbol;
  string private _baseURI;
  uint256 public nextTokenId;

  mapping(address => uint256) private _balances;
  mapping(uint256 => address) private _owners;
  mapping(uint256 => address) private _allowances;
  mapping(address => mapping(address => bool)) private _operatorApprovals;
  mapping(uint256 => string) private _tokenURIs;
  mapping(address => uint256[]) private _ownedTokens;

  event Mint(address indexed to, uint256 indexed tokenId, string tokenURI);

  error ZeroAddressNotAllowed(address addr);
  error NotAuthorized(address addr);
  error NotTokenOwner(address addr, uint256 tokenId);
  error TransferToNonERC721ReceiverImplementer();
  error InvalidOwner(address owner);
  error IndexOutOfBounds(uint256 index);
  error NonexistentToken(uint256 tokenId);
  error InvalidOperator(address operator);
  error MismatchedArrays(uint256 toLength, uint256 urisLength);

  constructor(string memory name_, string memory symbol_, address initialOwner) Ownable(initialOwner) {
    _name = name_;
    _symbol = symbol_;
  }

  function name() external view override returns (string memory) {
    return _name;
  }

  function symbol() external view override returns (string memory) {
    return _symbol;
  }

  function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
    return
      interfaceId == type(IERC165).interfaceId ||
      interfaceId == type(IERC721).interfaceId ||
      interfaceId == type(IERC721Metadata).interfaceId;
  }

  function mint(address to, string memory uri) public onlyOwner {
    if (to == address(0)) {
      revert ZeroAddressNotAllowed(to);
    }

    uint256 tokenId = nextTokenId;
    _owners[tokenId] = to;
    _balances[to]++;
    _tokenURIs[tokenId] = uri;
    _ownedTokens[to].push(tokenId);
    nextTokenId++;

    emit Transfer(address(0), to, tokenId);
    emit Mint(to, tokenId, uri);

    if (!_checkOnERC721Received(address(0), to, tokenId, '')) {
      revert TransferToNonERC721ReceiverImplementer();
    }
  }

  function mintBatch(address[] calldata to, string[] calldata uris) external onlyOwner {
    if (to.length != uris.length) {
      revert MismatchedArrays(to.length, uris.length);
    }

    for (uint256 i = 0; i < to.length; i++) {
      mint(to[i], uris[i]);
    }
  }

  function balanceOf(address owner) external view override returns (uint256 balance) {
    if (owner == address(0)) {
      revert InvalidOwner(address(0));
    }

    return _balances[owner];
  }

  function ownerOf(uint256 tokenId) external view override returns (address owner) {
    return _requireOwned(tokenId);
  }

  function getApproved(uint256 tokenId) external view override returns (address operator) {
    _requireOwned(tokenId);
    return _allowances[tokenId];
  }

  function safeTransferFrom(address from, address to, uint256 tokenId) external override {
    safeTransferFrom(from, to, tokenId, '');
  }

  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
    _transfer(from, to, tokenId);
    if (!_checkOnERC721Received(from, to, tokenId, data)) {
      revert TransferToNonERC721ReceiverImplementer();
    }
  }

  function transferFrom(address from, address to, uint256 tokenId) external override {
    _transfer(from, to, tokenId);
  }

  function approve(address to, uint256 tokenId) external override {
    address owner = _requireOwned(tokenId);
    // 在 ERC721 标准中，approve 函数允许代币所有者或被授权的操作员（operator）批准另一个地址转移特定的代币。
    if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) {
      revert NotAuthorized(msg.sender);
    }

    _approve(to, tokenId);
  }

  function setApprovalForAll(address operator, bool approved) external override {
    if (operator == address(0)) {
      revert InvalidOperator(operator);
    }

    _operatorApprovals[msg.sender][operator] = approved;
    emit ApprovalForAll(msg.sender, operator, approved);
  }

  function isApprovedForAll(address owner, address operator) external view override returns (bool) {
    return _operatorApprovals[owner][operator];
  }

  function totalSupply() external view returns (uint256) {
    return nextTokenId;
  }

  function tokenOfOwnerByIndex(address owner, uint256 index) external view override returns (uint256) {
    if (index >= _balances[owner]) {
      revert IndexOutOfBounds(index);
    }

    if (index >= _ownedTokens[owner].length) {
      revert IndexOutOfBounds(index);
    }

    return _ownedTokens[owner][index];
  }

  function tokenByIndex(uint256 index) external view override returns (uint256) {
    if (index >= nextTokenId) {
      revert NonexistentToken(index);
    }

    // equivalent to tokenId
    return index;
  }

  function _transfer(address from, address to, uint256 tokenId) internal {
    address owner = _requireOwned(tokenId);
    if (msg.sender != owner && _allowances[tokenId] != msg.sender && !_operatorApprovals[owner][msg.sender]) {
      revert NotAuthorized(msg.sender);
    }

    if (owner != from) {
      revert NotTokenOwner(from, tokenId);
    }

    if (to == address(0)) {
      revert ZeroAddressNotAllowed(to);
    }

    // 代币已经被转移了，所以需要清除原来的授权，确保之前的批准地址不再能够操作该代币
    _approve(address(0), tokenId);

    _balances[from] -= 1;
    _balances[to] += 1;
    _owners[tokenId] = to;

    _removeTokenFromOwnerEnumeration(from, tokenId);
    _ownedTokens[to].push(tokenId);

    emit Transfer(from, to, tokenId);
  }

  function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
    uint256 len = _ownedTokens[from].length;
    uint256 lastTokenIndex = len - 1;
    uint256 tokenIndex;

    for (uint256 i = 0; i < len; i++) {
      if (_ownedTokens[from][i] == tokenId) {
        tokenIndex = i;
        break;
      }
    }

    if (tokenIndex != lastTokenIndex) {
      uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];
      _ownedTokens[from][tokenIndex] = lastTokenId;
    }

    _ownedTokens[from].pop();
  }

  function _approve(address to, uint256 tokenId) internal {
    _allowances[tokenId] = to;
    emit Approval(_owners[tokenId], to, tokenId);
  }

  function _requireOwned(uint256 tokenId) internal view returns (address) {
    address owner = _owners[tokenId];
    if (owner == address(0)) {
      revert NonexistentToken(tokenId);
    }

    return owner;
  }

  function burn(uint256 tokenId) external onlyOwner {
    address owner = _requireOwned(tokenId);

    _approve(address(0), tokenId);

    _balances[owner] -= 1;

    _removeTokenFromOwnerEnumeration(owner, tokenId);

    delete _owners[tokenId];
    delete _tokenURIs[tokenId];

    emit Transfer(owner, address(0), tokenId);
  }

  function setBaseURI(string memory uri) public onlyOwner {
    _baseURI = uri;
  }

  function _getBaseURI() internal view virtual returns (string memory) {
    return _baseURI;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    _requireOwned(tokenId);

    string memory baseURI = _getBaseURI();
    string memory tokenURI_ = _tokenURIs[tokenId];
    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenURI_)) : tokenURI_;
  }

  // 用于在执行 ERC-721 代币转移时，确保接收方合约实现了 IERC721Receiver 接口。
  // 这个函数的主要目的是防止代币被转移到不支持 ERC-721 接口的合约地址，从而避免代币丢失。
  function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private returns (bool) {
    // 使用 to.code.length > 0 检查接收方地址是否是一个合约地址
    if (to.code.length > 0) {
      // 尝试调用接收方合约的 onERC721Received 方法
      try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
        // 检查返回值是否等于 IERC721Receiver.onERC721Received.selector
        return retval == IERC721Receiver.onERC721Received.selector;
      } catch (bytes memory reason) {
        // 如果调用失败，检查 reason 的长度
        if (reason.length == 0) {
          // 如果 reason 为空，抛出 TransferToNonERC721ReceiverImplementer 错误
          revert TransferToNonERC721ReceiverImplementer();
        } else {
          // 否则，使用内联汇编抛出错误信息
          // solhint-disable-next-line no-inline-assembly
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      // 如果接收方地址不是合约，直接返回 true
      return true;
    }
  }
}
