var ConvertLib = artifacts.require("./ConvertLib.sol");
var MetaCoin = artifacts.require("./MetaCoin.sol");

var BotCoin = artifacts.require("./BotCoin.sol");
//var BotCoinSale = artifacts.require("./BotCoinSale.sol");

module.exports = function(deployer) {
  deployer.deploy(ConvertLib);
  deployer.link(ConvertLib, MetaCoin);
  deployer.deploy(MetaCoin);

  deployer.deploy(BotCoin);
  //deployer.deploy(BotCoinSale);
};
