require('babel-register');
require('babel-polyfill');

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      gas: 4712388,
      network_id: "*" // Match any network id
    }
  }
};
