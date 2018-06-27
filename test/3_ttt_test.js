import expectThrow from 'openzeppelin-solidity/test/helpers/expectThrow'
import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'

// const Game = artifacts.require('./TTTGame.sol');
const Controller = artifacts.require('./Controller.sol')

// const newActionEncoder = (lib) => (...args) => lib.encodeAction.call(...args)
const encodeActionABI = (x, y) => eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'], [x, y]))

contract('TTTGame + Controller + Connect', (accounts) => {
  let controller
  let encodeAction
  const player1 = accounts[0]
  const player2 = accounts[1]
  before('get the encode action function', async () => {
    // const gameLib = await Game.deployed()
    // encodeAction = newActionEncoder(gameLib)
    encodeAction = encodeActionABI
  })
  beforeEach('deploy a new Controller', async () => {
    controller = await Controller.new(player1, player2)
  })
  describe('constructor', () => {
    it('should set player addresses and control correctly', async () => {
      const instance = await Controller.new(player1, player2)
      assert.equal(await instance.player1(), player1)
      assert.equal(await instance.player2(), player2)
      assert.equal(await instance.control(), 1)
    })
  })
  describe('deposit', () => {

  })
  describe('play', () => {
    beforeEach('setup game', async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.deposit({
        from: player1,
        value: bet
      })
      await controller.deposit({
        from: player2,
        value: bet
      })
    })
    it('should only allow player who has control to play', async () => {
      const tx = await controller.play(encodeAction(0, 0), { from: player1 })
      assert.equal(tx.logs[0].event, 'LogPlayerMove')
      assert.equal(tx.logs[0].args.player, player1)
    })
    it('should not allow player who does not have control to play', async () => {
      await expectThrow(controller.play(encodeAction(0, 0), { from: player2 }))
    })
    it('control should alternate', async () => {
      await controller.play(encodeAction(0, 0), { from: player1 })
      assert.equal(await controller.control(), 2)
      await expectThrow(controller.play(encodeAction(0, 1), { from: player1 }))
    })
  })
  describe('payout', () => {
    beforeEach('setup game', async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.deposit({
        from: player1,
        value: bet
      })
      await controller.deposit({
        from: player2,
        value: bet
      })
    })
    it('should pay the winner when player 1 wins', async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.play(encodeAction(0, 0), { from: player1 })
      await controller.play(encodeAction(0, 1), { from: player2 })
      await controller.play(encodeAction(1, 1), { from: player1 })
      await controller.play(encodeAction(0, 2), { from: player2 })
      await controller.play(encodeAction(2, 2), { from: player1 })
      const tx = await controller.payout({ from: player1 })
      assert.equal(tx.logs[0].event, 'LogPayout')
      assert.equal(tx.logs[0].args.player, player1)
      assert.equal(tx.logs[0].args.amount.toString(), bet.mul(2).toString())
    })
    it('should split the payout if match is a draw', async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.play(encodeAction(1, 1), { from: player1 })
      await controller.play(encodeAction(1, 0), { from: player2 })
      await controller.play(encodeAction(0, 0), { from: player1 })
      await controller.play(encodeAction(2, 2), { from: player2 })
      await controller.play(encodeAction(2, 0), { from: player1 })
      await controller.play(encodeAction(0, 2), { from: player2 })
      await controller.play(encodeAction(1, 2), { from: player1 })
      await controller.play(encodeAction(0, 1), { from: player2 })
      await controller.play(encodeAction(2, 1), { from: player1 })
      const tx = await controller.payout({ from: player1 })
      assert.equal(tx.logs[0].event, 'LogPayout')
      assert.equal(tx.logs[0].args.player, player1)
      assert.equal(tx.logs[0].args.amount.toString(), bet.toString())
      assert.equal(tx.logs[1].event, 'LogPayout')
      assert.equal(tx.logs[1].args.player, player2)
      assert.equal(tx.logs[1].args.amount.toString(), bet.toString())
    })
    it('should not allow payout before terminal state', async () => {
      await controller.play(encodeAction(1, 1), { from: player1 })
      await controller.play(encodeAction(1, 0), { from: player2 })
      await controller.play(encodeAction(0, 0), { from: player1 })
      expectThrow(controller.payout({ from: player1 }))
    })
  })
})
