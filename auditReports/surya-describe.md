- MyToken (IERC20, Ownable, Pausable, ReentrancyGuard)
  - [Pub] <Constructor> #
    - modifiers: Ownable
  - [Ext] totalSupply
  - [Ext] balanceOf
  - [Int] \_transfer #
  - [Ext] transfer #
    - modifiers: whenNotPaused,notBlacklisted,checkCooldown,nonReentrant
  - [Ext] allowance
  - [Ext] approve #
  - [Ext] transferFrom #
    - modifiers: whenNotPaused,notBlacklisted,checkCooldown,nonReentrant
  - [Ext] mint #
    - modifiers: onlyOwner
  - [Ext] burn #
  - [Ext] setMaxTransferAmount #
    - modifiers: onlyOwner
  - [Ext] setCooldownPeriod #
    - modifiers: onlyOwner
  - [Ext] updateBlacklist #
    - modifiers: onlyOwner
  - [Ext] pause #
    - modifiers: onlyOwner
  - [Ext] unpause #
    - modifiers: onlyOwner
  - [Ext] recoverTokens #
    - modifiers: onlyOwner
  - [Ext] batchTransfer #
    - modifiers: whenNotPaused,nonReentrant

($) = payable function

# = non-constant function
