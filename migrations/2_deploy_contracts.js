const Util = artifacts.require("./Util.sol")
const Controller = artifacts.require("./Controller.sol")
const Game = artifacts.require("./TTTGame.sol")

module.exports = (deployer, network, accounts) => {
  deployer.deploy(Util)
  deployer.link(Util, [Game, Controller])
  deployer.deploy(Game)
  deployer.link(Game, Controller)
}
