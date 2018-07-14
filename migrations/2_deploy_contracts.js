const BytesUtil = artifacts.require('BytesUtil')
const Controller = artifacts.require('Controller')
const Game = artifacts.require('TTTGame')

module.exports = (deployer, network, accounts) => {
  deployer.deploy(BytesUtil)
  deployer.link(BytesUtil, [Game, Controller])
  deployer.deploy(Game)
  deployer.link(Game, Controller)
}
