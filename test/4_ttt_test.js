import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'
import XRandomJS from './helpers/xrandom'

// const Game = artifacts.require('TTTGame');
const Controller = artifacts.require('Controller')

// const newActionEncoder = (lib) => (...args) => lib.encodeAction.call(...args)
const encodeActionABI = (x, y) => eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'], [x, y]))
const newCommit = (v) => eutil.bufferToHex(XRandomJS.newCommit(v))

contract('TTTGame + Controller', (accounts) => {
  let controller
  let encodeAction
  const [, player1, player2] = accounts
  before('get the encode action function', async () => {
    // const gameLib = await Game.deployed()
    // encodeAction = newActionEncoder(gameLib)
    encodeAction = encodeActionABI
  })
  beforeEach('deploy a new Controller', async () => {
    controller = await Controller.new([player1, player2])
  })
  describe('constructor', () => {
    it('should set player addresses correctly', async () => {
      const instance = await Controller.new([player1, player2])
      assert.equal(await instance.players(player1), 1)
      assert.equal(await instance.players(player2), 2)
    })
  })
  describe('start', () => {
    beforeEach('deposit', async () => {
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
    it('should let player 1 go first if random number is even', async () => {
      await controller.commit(newCommit(1337), { from: player1 })
      await controller.commit(newCommit(9001), { from: player2 })
      await controller.revealAndCommit(1337, newCommit(1338), { from: player1 })
      await controller.revealAndCommit(9001, newCommit(9002), { from: player2 })
      await controller.start()
      // the 1st number: sha3(1337 xor 9001) is
      // 0x4e66df4bdd547b751802471b8578ff25842645c69676a953cff51ab97f0006e6
      // player 1 should go first
      assert.equal(await controller.control(), 1)
    })
    it('should let player 2 go first if random number is odd', async () => {
      await controller.commit(newCommit(1337), { from: player1 })
      await controller.commit(newCommit(9002), { from: player2 })
      await controller.revealAndCommit(1337, newCommit(1338), { from: player1 })
      await controller.revealAndCommit(9002, newCommit(9002), { from: player2 })
      await controller.start()
      // the 1st number: sha3(1337 xor 9002) is
      // 0xd93d05651913279338de2ec0ab00dc6a13dc8c75c48a9de906cdc7712b825875
      // player 2 should go first
      assert.equal(await controller.control(), 2)
    })
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
      await controller.commit(newCommit(1337), { from: player1 })
      await controller.commit(newCommit(9001), { from: player2 })
      await controller.revealAndCommit(1337, newCommit(1338), { from: player1 })
      await controller.revealAndCommit(9001, newCommit(1338), { from: player2 })
      await controller.start()
    })
    it('should only allow player who has control to play', async () => {
      const tx = await controller.play(encodeAction(0, 0), { from: player1 })
      assert.equal(tx.logs[0].event, 'LogPlayerMove')
      assert.equal(tx.logs[0].args.player, player1)
    })
    it('should not allow player who does not have control to play', async () => {
      await assertRevert(controller.play(encodeAction(0, 0), { from: player2 }))
    })
    it('control should alternate', async () => {
      await controller.play(encodeAction(0, 0), { from: player1 })
      assert.equal(await controller.control(), 2)
      await assertRevert(controller.play(encodeAction(0, 1), { from: player1 }))
    })
  })
  describe('withdraw', () => {
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
      await controller.commit(newCommit(1337), { from: player1 })
      await controller.commit(newCommit(9001), { from: player2 })
      await controller.revealAndCommit(1337, newCommit(1338), { from: player1 })
      await controller.revealAndCommit(9001, newCommit(9002), { from: player2 })
      await controller.start()
    })
    it('should pay player 1 when player 1 wins', async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.play(encodeAction(0, 0), { from: player1 })
      await controller.play(encodeAction(0, 1), { from: player2 })
      await controller.play(encodeAction(1, 1), { from: player1 })
      await controller.play(encodeAction(0, 2), { from: player2 })
      await controller.play(encodeAction(2, 2), { from: player1 })
      await controller.end()
      const tx = await controller.withdraw({ from: player1 })
      assert.equal(tx.logs[0].event, 'LogWithdraw')
      assert.equal(tx.logs[0].args.player, player1)
      assert.equal(tx.logs[0].args.amount.toString(), bet.mul(2).toString())
    })
    it('should split the payout if match is a draw', async () => {
      const bet = await controller.BET_AMOUNT()
      // fill up the board without anyone winning
      await controller.play(encodeAction(1, 1), { from: player1 })
      await controller.play(encodeAction(1, 0), { from: player2 })
      await controller.play(encodeAction(0, 0), { from: player1 })
      await controller.play(encodeAction(2, 2), { from: player2 })
      await controller.play(encodeAction(2, 0), { from: player1 })
      await controller.play(encodeAction(0, 2), { from: player2 })
      await controller.play(encodeAction(1, 2), { from: player1 })
      await controller.play(encodeAction(0, 1), { from: player2 })
      await controller.play(encodeAction(2, 1), { from: player1 })
      await controller.end()
      const tx = await controller.withdraw({ from: player1 })
      assert.equal(tx.logs[0].event, 'LogWithdraw')
      assert.equal(tx.logs[0].args.player, player1)
      assert.equal(tx.logs[0].args.amount.toString(), bet.toString())
      const tx2 = await controller.withdraw({ from: player2 })
      assert.equal(tx2.logs[0].event, 'LogWithdraw')
      assert.equal(tx2.logs[0].args.player, player2)
      assert.equal(tx2.logs[0].args.amount.toString(), bet.toString())
    })
    it('should not allow withdraw before terminal state', async () => {
      await controller.play(encodeAction(1, 1), { from: player1 })
      await controller.play(encodeAction(1, 0), { from: player2 })
      await controller.play(encodeAction(0, 0), { from: player1 })
      await assertRevert(controller.end())
      await assertRevert(controller.withdraw({ from: player1 }))
    })
  })
})
