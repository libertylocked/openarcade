const TTTController = artifacts.require("./TTTController.sol")
const TTTLib = artifacts.require("./TTTLib.sol")

module.exports = (deployer, network, accounts) => {
  deployer.deploy(TTTLib)
  deployer.link(TTTLib, TTTController)
  deployer.deploy(TTTController, accounts[0], accounts[1])
}
