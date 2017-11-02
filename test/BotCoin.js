'use strict';

import expectThrow from './helpers/expectThrow';

const BotCoin = artifacts.require('../contracts/BotCoin.sol');

const BOT_DECIMALS = 9;

contract('BotCoin', function(accounts) {

  let token;

  beforeEach(async function() {
    token = await BotCoin.new();
  });

  // TODO : rozhkov 
  it('should have rigth metadata', async function () {
    let name = await token.name();
    let symbol = await token.symbol();
    let decimals = await token.decimals();

    assert.equal(name, "BotCoin");
    assert.equal(symbol, "BOT");
    assert.equal(decimals, BOT_DECIMALS);
  });

  it('should start with a totalSupply of 0', async function() {
    let totalSupply = await token.totalSupply();

    assert.equal(totalSupply, 0);
  });

  it('should return mintingFinished false after construction', async function() {
    let mintingFinished = await token.mintingFinished();

    assert.equal(mintingFinished, false);
  });

  it('should mint a given amount of tokens to a given address', async function() {
    const result = await token.mint(accounts[0], 100);
    assert.equal(result.logs[0].event, 'Mint');
    assert.equal(result.logs[0].args.to.valueOf(), accounts[0]);
    assert.equal(result.logs[0].args.amount.valueOf(), 100);
    assert.equal(result.logs[1].event, 'Transfer');
    assert.equal(result.logs[1].args.from.valueOf(), 0x0);

    let balance0 = await token.balanceOf(accounts[0]);
    assert(balance0, 100);

    let totalSupply = await token.totalSupply();
    assert(totalSupply, 100);
  });

  it('should fail to mint after call to finishMinting', async function () {
    await token.finishMinting();
    assert.equal(await token.mintingFinished(), true);
    await expectThrow(token.mint(accounts[0], 100));
  });

  // TODO : 
  it('should fail to transfer before call to finishMinting', async function () {
    await token.mint(accounts[0], 100);

    await expectThrow(token.transfer(accounts[1], 10));

    await token.approve(accounts[1], 10);
    await expectThrow(token.transferFrom(accounts[0], accounts[1], 10, {from: accounts[1]}));

    assert.equal(await token.balanceOf(accounts[0]), 100);
    assert.equal(await token.balanceOf(accounts[1]), 0);
  });
  
  // TODO : 
  it('should transfer after call to finishMinting', async function () {
    await token.mint(accounts[0], 100);
    await token.finishMinting();

    await token.transfer(accounts[1], 10);

    await token.approve(accounts[2], 10);
    await token.transferFrom(accounts[0], accounts[2], 10, {from: accounts[2]});

    assert.equal(await token.balanceOf(accounts[0]), 80);
    assert.equal(await token.balanceOf(accounts[1]), 10);
    assert.equal(await token.balanceOf(accounts[2]), 10);
  });

});
