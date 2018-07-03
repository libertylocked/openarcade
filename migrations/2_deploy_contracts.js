const Util = artifacts.require("./Util.sol")
const RandGen = artifacts.require("./RandGen.sol")
const Controller = artifacts.require("./Controller.sol")
const Game = artifacts.require("./TTTGame.sol")

module.exports = (deployer, network, accounts) => {
  deployer.deploy(RandGen, [accounts[0], accounts[1]])
  deployer.deploy(Util)
  deployer.link(Util, [Game, Controller])
  deployer.deploy(Game)
  deployer.link(Game, Controller)
}
