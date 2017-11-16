pragma solidity ^0.4.17;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/ownership/HasNoTokens.sol';
import './BotTCoin.sol';

/**
 * @title BotTCoinSale
 */

contract BotTCoinSale is Ownable, HasNoTokens {

  using SafeMath for uint256;

  //uint256 private constant E18 = 10**18;
  //uint256 private constant ETH_DECIMALS = 18;
  //uint256 private constant BOT_DECIMALS = 9;
  //uint256 private constant BOT_PER_ETH = 10000;

  // minimum purchase amount in weis (1 BOT = 0.0001 ETH)
  uint256 private constant MIN_VALUE = 100000000000000;

  // The token being sold
  BotTCoin public token;

  // address where funds are collected
  address public wallet;

  // how many token units a buyer gets per 100000 wei
  uint256 public rate = 100000;

  // amount of raised tokens
  uint256 public tokensRaised;

  // amount of raised money in wei
  uint256 public weiRaised;

  // isFinalized
  bool public isFinalized = false;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  // Finalized event
  event Finalized();

  function BotTCoinSale(address _wallet) public {
    require(_wallet != address(0));

    token = new BotTCoin(); // create or arg

  }

  // fallback function can be used to buy tokens
  function() public payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
    require(beneficiary != address(0));
    require(validPurchase());

    address purchaser = msg.sender;
    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 tokens = calculateTokens(weiAmount);

    // update state

    tokensRaised = tokensRaised.add(tokens);
    weiRaised = weiRaised.add(weiAmount);

    token.mint(beneficiary, tokens);
    TokenPurchase(purchaser, beneficiary, weiAmount, tokens);

    forwardFunds();
  }

  // calculate token amount to be created
  function calculateTokens(uint256 weiAmount) public constant returns (uint256) {
    return weiAmount.div(rate);
  }

  // send ether to the fund collection wallet
  function forwardFunds() internal {
    wallet.transfer(this.balance);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal constant returns (bool) {
    bool validMinValue = msg.value >= MIN_VALUE;
    return validMinValue;
  }

  /**
   * @dev Must be called after crowdsale ends, to do some extra finalization
   * work. Calls the contract's finalization function.
   */
  function finalize() onlyOwner public {
    require(!isFinalized);

    finalization();
    Finalized();

    isFinalized = true;
  }

  // finalization task, called when owner calls finalize()
  function finalization() internal {
    token.finishMinting();
    token.transferOwnership(owner);
  }

  /**
   * @dev Transfers the current balance to the owner and terminates the contract.
   */
  function destroy() onlyOwner public {
    selfdestruct(owner);
  }

}
