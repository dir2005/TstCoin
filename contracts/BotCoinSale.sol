pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import './BotCoin.sol';

/**
 * @title BotCoinSale
 */

contract BotCoinSale is Ownable {

  using SafeMath for uint256;

  //uint256 private constant E18 = 10**18;

  //uint256 private constant ETH_DECIMALS = 18;

  //uint256 private constant BOT_DECIMALS = 9;

  //uint256 private constant BOT_PER_ETH = 10000;

  // minimum purchase amount in weis (1 BOT = 0.0001 ETH)
  uint256 private constant MIN_VALUE = 100000000000000;

  enum State { Active, Refunding, Closed }

  State public state;

  // The token being sold
  BotCoin public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where funds are collected
  address public wallet;

  // how many token units a buyer gets per 100000 wei
  uint256 public rate = 100000;

  // amount of raised tokens
  uint256 public tokensRaised;

  // amount of raised money in wei
  uint256 public weiRaised;

  // amount of raised money in wei
  mapping (address => uint256) public weiBalances;

  // minimum amount of funds to be raised in weis
  uint256 public softCap;

  // maximum amount of funds to be raised in weis
  uint256 public hardCap;

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

  event RefundsEnabled();
  event Refunded(address indexed purchaser, uint256 weiAmount);

  // TODO : TEST
  event Log(uint256 data);
  event LogAddr(address addr);

  function BotCoinSale(uint256 _startTime, uint256 _endTime, uint256 _softCap, uint256 _hardCap, address _wallet) public {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_softCap > 0);
    require(_hardCap > 0);
    require(_softCap <= _hardCap);
    require(_wallet != address(0));

    token = new BotCoin(); // create or arg
    startTime = _startTime;
    endTime = _endTime;
    softCap = _softCap;
    hardCap = _hardCap;
    wallet = _wallet;

    state = State.Active;
  }

/*
  ///////////////////////////////////Tokens miniting to WINGS rewards contract
  //Is currently in the period after the private start time and before the public start time.
  modifier is_pre_crowdfund_period() {
    if (now >= publicStartTime || now < privateStartTime) throw;
    _;
  }
  // Tokens issuance that can only be called by project creators and only during the pre-crowdfund
  function allocateWings()
    payable
    is_pre_crowdfund_period
    only_creator
  {
    prebuyPortionTotal += amount;
    if (!Token.createToken(wingsAddress, o_amount)) throw;
    tokenSold += o_amount;
    etherRaised += msg.value;
  }
*/

  // fallback function can be used to buy tokens
  function () public payable {
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

    weiBalances[purchaser] = weiBalances[purchaser].add(weiAmount);

    token.mint(beneficiary, tokens);
    TokenPurchase(purchaser, beneficiary, weiAmount, tokens);

    //forwardFunds(); // TODO : forwardFunds after finalize
  }

  // calculate token amount to be created
  function calculateTokens(uint256 weiAmount) internal constant returns (uint256) {
    return weiAmount.div(rate);
  }

  // send ether to the fund collection wallet
  function forwardFunds() internal {
    wallet.transfer(this.balance);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal constant returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value >= MIN_VALUE;
    bool withinCap = weiRaised.add(msg.value) <= hardCap;
    return withinPeriod && nonZeroPurchase && withinCap;
  }

  // @return true if crowdsale event has ended
  function hasEnded() public constant returns (bool) {
    bool afterEnd = now > endTime;
    bool capReached = weiRaised >= hardCap;
    return afterEnd || capReached;
  }

  // if crowdsale is unsuccessful, investors can claim refunds here
  function claimRefund() public {
    require(isFinalized);
    require(!goalReached());

    refund(msg.sender);
  }

  /**
   * @dev Must be called after crowdsale ends, to do some extra finalization
   * work. Calls the contract's finalization function.
   */
  function finalize() onlyOwner public {
    require(!isFinalized);
    require(hasEnded());

    finalization();
    Finalized();

    isFinalized = true;
  }

  function goalReached() public constant returns (bool) {
    return weiRaised >= softCap;
  }

  // vault finalization task, called when owner calls finalize()
  function finalization() internal {
    if (goalReached()) {
      close();

      // TODO : allocate restrictedTokens

    } else {
      enableRefunds();
    }
    token.finishMinting();
    token.transferOwnership(owner);
  }

  function close() onlyOwner internal {
    require(state == State.Active);
    state = State.Closed;
    //Closed();
    wallet.transfer(this.balance); // forwardFunds
  }

  function enableRefunds() onlyOwner internal {
    require(state == State.Active);
    state = State.Refunding;
    RefundsEnabled();
  }

  function refund(address purchaser) public {
    // TODO : exclude preSale investors but include preCommitments
    require(state == State.Refunding);
    uint256 weiAmount = weiBalances[purchaser];
    weiBalances[purchaser] = 0;
    purchaser.transfer(weiAmount);
    Refunded(purchaser, weiAmount);
  }

}
