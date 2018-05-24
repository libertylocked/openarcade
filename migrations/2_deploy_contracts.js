const TTTController = artifacts.require("./TTTController.sol")
const TTTLibrary = artifacts.require("./TTTLibrary.sol")

module.exports = (deployer, network, accounts) => {
  deployer.deploy(TTTLibrary)
  deployer.link(TTTLibrary, TTTController)
  deployer.deploy(TTTController, accounts[0], accounts[1])
}
