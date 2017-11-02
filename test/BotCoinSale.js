import ether from './helpers/ether';
import {advanceBlock} from './helpers/advanceToBlock';
import {increaseTimeTo, duration} from './helpers/increaseTime';
import latestTime from './helpers/latestTime';
import EVMThrow from './helpers/EVMThrow';

const BigNumber = web3.BigNumber;

const should = require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const BotCoinSale = artifacts.require('BotCoinSale');
const BotCoin = artifacts.require('BotCoin');

//const E18 = 10**18;
const ETH_DECIMALS = 18;
const BOT_DECIMALS = 9;

contract('BotCoinSale', function ([_owner, wallet, purchaser, investor]) {

  const value = ether(1); // 4.2, 42
  const rate = new BigNumber(10000);
  const softCap = new ether(2); // 20000 BOT
  const hardCap = new ether(3); // 30000 BOT

  const expectedTokenAmount = rate.mul(value).mul(10**(BOT_DECIMALS - ETH_DECIMALS));

  before(async function() {
    //Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });

  beforeEach(async function () {
    this.startTime = latestTime() + duration.weeks(1);
    this.endTime =   this.startTime + duration.weeks(1);
    this.afterEndTime = this.endTime + duration.seconds(1);

    this.crowdsale = await BotCoinSale.new(this.startTime, this.endTime, softCap, hardCap, wallet);
    
    this.token = BotCoin.at(await this.crowdsale.token());
  });

  it('should be token owner', async function () {
    const owner = await this.token.owner();
    owner.should.equal(this.crowdsale.address);
  });

  it('should be ended only after end', async function () {
    let ended = await this.crowdsale.hasEnded();
    ended.should.equal(false);
    await increaseTimeTo(this.afterEndTime);
    ended = await this.crowdsale.hasEnded();
    ended.should.equal(true);
  });

  describe('accepting payments', function () {

    it('should reject payments before start', async function () {
      await this.crowdsale.send(value).should.be.rejectedWith(EVMThrow);
      await this.crowdsale.buyTokens(investor, {value: value, from: purchaser}).should.be.rejectedWith(EVMThrow);
    });

    it('should accept payments after start', async function () {
      await increaseTimeTo(this.startTime);
      await this.crowdsale.send(value).should.be.fulfilled;
      await this.crowdsale.buyTokens(investor, {value: value, from: purchaser}).should.be.fulfilled;
    });

    it('should reject payments after end', async function () {
      await increaseTimeTo(this.afterEndTime);
      await this.crowdsale.send(value).should.be.rejectedWith(EVMThrow);
      await this.crowdsale.buyTokens(investor, {value: value, from: purchaser}).should.be.rejectedWith(EVMThrow);
    });

  });

  describe('high-level purchase', function () {

    beforeEach(async function() {
      await increaseTimeTo(this.startTime);
    })

    it('should log purchase', async function () {
      const {logs} = await this.crowdsale.sendTransaction({value: value, from: investor});

      const event = logs.find(e => e.event === 'TokenPurchase');

      should.exist(event);
      event.args.purchaser.should.equal(investor);
      event.args.beneficiary.should.equal(investor);
      event.args.value.should.be.bignumber.equal(value);
      event.args.amount.should.be.bignumber.equal(expectedTokenAmount);
    });

    it('should increase totalSupply', async function () {
      await this.crowdsale.send(value);
      const totalSupply = await this.token.totalSupply();
      totalSupply.should.be.bignumber.equal(expectedTokenAmount);
    });

    it('should assign tokens to sender', async function () {
      await this.crowdsale.sendTransaction({value: value, from: investor});
      let balance = await this.token.balanceOf(investor);
      balance.should.be.bignumber.equal(expectedTokenAmount);
    });

    it('should not forward funds to wallet before finalization', async function () {
      const pre = web3.eth.getBalance(wallet);
      await this.crowdsale.sendTransaction({value, from: investor});
      const post = web3.eth.getBalance(wallet);
      post.should.be.bignumber.equal(pre);
    });

  });

  describe('low-level purchase', function () {

    beforeEach(async function() {
      await increaseTimeTo(this.startTime);
    });

    it('should log purchase', async function () {
      const {logs} = await this.crowdsale.buyTokens(investor, {value: value, from: purchaser});

      const event = logs.find(e => e.event === 'TokenPurchase');

      should.exist(event);
      event.args.purchaser.should.equal(purchaser);
      event.args.beneficiary.should.equal(investor);
      event.args.value.should.be.bignumber.equal(value);
      event.args.amount.should.be.bignumber.equal(expectedTokenAmount);
    });

    it('should increase totalSupply', async function () {
      await this.crowdsale.buyTokens(investor, {value, from: purchaser});
      const totalSupply = await this.token.totalSupply();
      totalSupply.should.be.bignumber.equal(expectedTokenAmount);
    });

    it('should assign tokens to beneficiary', async function () {
      await this.crowdsale.buyTokens(investor, {value, from: purchaser});
      const balance = await this.token.balanceOf(investor);
      balance.should.be.bignumber.equal(expectedTokenAmount);
    });

    it('should not forward funds to wallet before finalization', async function () {
      const pre = web3.eth.getBalance(wallet);
      await this.crowdsale.buyTokens(investor, {value, from: purchaser});
      const post = web3.eth.getBalance(wallet);
      post.should.be.bignumber.equal(pre);
    });

  });

  it('should reject payments over cap', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.send(hardCap);
    await this.crowdsale.send(1).should.be.rejectedWith(EVMThrow);
  });

  it('should allow finalization and transfer funds to wallet if the goal is reached', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.send(hardCap);

    const beforeFinalization = web3.eth.getBalance(wallet);
    await increaseTimeTo(this.afterEndTime);
    await this.crowdsale.finalize({from: _owner});
    const afterFinalization = web3.eth.getBalance(wallet);

    afterFinalization.minus(beforeFinalization).should.be.bignumber.equal(hardCap);
  });

  it('should allow refunds if the goal is not reached', async function () {
    const balanceBeforeInvestment = web3.eth.getBalance(investor);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.sendTransaction({value: ether(1), from: investor, gasPrice: 0});
    await increaseTimeTo(this.afterEndTime);

    await this.crowdsale.finalize({from: _owner});
    await this.crowdsale.claimRefund({from: investor, gasPrice: 0}).should.be.fulfilled;

    const balanceAfterRefund = web3.eth.getBalance(investor);
    balanceBeforeInvestment.should.be.bignumber.equal(balanceAfterRefund);
  });

  it('should token owner after finalization', async function () {
    await increaseTimeTo(this.afterEndTime);
    await this.crowdsale.finalize({from: _owner});
    
    const owner = await this.token.owner();
    owner.should.equal(_owner);
  });

});
