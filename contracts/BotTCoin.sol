pragma solidity ^0.4.17;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';
import 'zeppelin-solidity/contracts/ownership/HasNoTokens.sol';
import 'zeppelin-solidity/contracts/ownership/HasNoEther.sol';

contract BotTCoin is MintableToken, HasNoTokens, HasNoEther {

  string public constant name = "BOTT";
  string public constant symbol = "BOTT";
  uint8 public constant decimals = 9;

  /**
   * @dev Transfers the current balance to the owner and terminates the contract.
   */
  function destroy() onlyOwner public {
    selfdestruct(owner);
  }

}
