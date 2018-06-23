const PlatformLib = artifacts.require("./PlatformLib.sol")
const TTTLib = artifacts.require("./TTTLib.sol")
const TTTController = artifacts.require("./TTTController.sol")

module.exports = (deployer, network, accounts) => {
  deployer.deploy(PlatformLib)
  deployer.link(PlatformLib, TTTController)
  deployer.deploy(TTTLib)
  deployer.link(TTTLib, TTTController)
  deployer.deploy(TTTController, accounts[0], accounts[1])
}
