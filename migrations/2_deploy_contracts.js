const BytesUtil = artifacts.require('BytesUtil')
const Controller = artifacts.require('Controller')
const Game = artifacts.require('TTTGame')

module.exports = (deployer, network, accounts) => {
  deployer.deploy(BytesUtil)
  deployer.link(BytesUtil, [Game, Controller])
  deployer.deploy(Game)
  deployer.link(Game, Controller)
  deployer.deploy(Controller, [accounts[0], accounts[1]],
    web3.toWei(1, 'ether'), 10, 10)
}
