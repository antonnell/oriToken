var OriginToken = artifacts.require("OriginToken.sol");

module.exports = function(deployer) {
  deployer.deploy(OriginToken);
};
