pragma solidity ^0.4.17;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';

contract BotCoin is MintableToken {

  string public constant name = "BotCoin";
  string public constant symbol = "BOT";
  uint8 public constant decimals = 9;

  bool public transferAllowed = false;

  // TODO : PausableToken
  modifier canTransfer() {
    require(transferAllowed);
    _;
  }

  function allowTransfer() onlyOwner internal {
    transferAllowed = true;
  }

  function transfer(address _to, uint256 _value) canTransfer public returns (bool) {
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) canTransfer public returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  /**
   * @dev Function to stop minting new tokens.
   * @return True if the operation was successful.
   */
  function finishMinting() onlyOwner public returns (bool) {
    allowTransfer();
    return super.finishMinting();
  }

}
