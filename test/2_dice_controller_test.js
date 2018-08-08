import advanceToBlock from 'openzeppelin-solidity/test/helpers/advanceToBlock'
import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'
import XRandomJS from './helpers/xrandom'

const Controller = artifacts.require('DiceController')

const encodeActionABI = (roll) => eutil.bufferToHex(abi.rawEncode(['uint256'], [roll]))
const newCommit = (v) => eutil.bufferToHex(XRandomJS.newCommit(v))
const getBetAmount = (controller) => controller.betAmount.call()
const getMinTimerDuration = (controller) => controller.minTimerDuration.call()
const setupGame = async (controller, p1, p2) => {
  const bet = await getBetAmount(controller)
  await controller.deposit({ from: p1, value: bet })
  await controller.deposit({ from: p2, value: bet })
  await controller.commit(newCommit(1337), { from: p1 })
  await controller.commit(newCommit(9001), { from: p2 })
  await controller.revealAndCommit(1337, newCommit(1338), { from: p1 })
  await controller.revealAndCommit(9001, newCommit(9002), { from: p2 })
  // make the game 2 rounds
  await controller.start(encodeActionABI(2))
}

contract('Dice Controller', (accounts) => {
  let controller
  let encodeAction
  const [, player1, player2] = accounts
  before('get the encode action function', async () => {
    encodeAction = encodeActionABI
  })
  beforeEach('deploy a new controller', async () => {
    controller = await Controller.new([player1, player2],
      web3.toWei(0.1, 'ether'), 5, 5)
  })
  describe('timeout during playing', () => {
    describe('start timer', () => {
      it('should allow starting timer when RNG not ready', async () => {
        await setupGame(controller, player1, player2)
        // player 1 makes a move, RNG becomes not ready
        await controller.play(encodeAction(1), { from: player1 })
        const minDuration = await getMinTimerDuration(controller)
        // state becomes S2-0 (turn 2, RNG not ready)
        const tx = await controller.startTimer(minDuration, { from: player1 })
        assert.equal(tx.logs[0].event, 'LogTimerStarted')
        assert.equal(tx.logs[0].args.turn, 2)
        assert.isFalse(tx.logs[0].args.rngReady)
      })
    })
    describe('timeout', () => {
      it('should end the game if RNG ring turn player misses deadline', async () => {
        await setupGame(controller, player1, player2)
        // player 1 makes a move, RNG becomes not ready (S2-0)
        // now control is player2, but RNG turn is player1
        await controller.play(encodeAction(1), { from: player1 })
        const minDuration = await getMinTimerDuration(controller)
        const betAmount = await getBetAmount(controller)
        await controller.startTimer(minDuration, { from: player2 })
        await advanceToBlock(minDuration.plus(web3.eth.blockNumber))
        await controller.timeout({ from: player2 })
        // player2 should get all the funds since player1 missed RNG ring turn
        const tx = await controller.withdraw({ from: player2 })
        assert.equal(tx.logs[0].event, 'LogWithdraw')
        assert.equal(tx.logs[0].args.player, player2)
        assert.equal(tx.logs[0].args.amount.toString(16), betAmount.mul(2).toString(16))
      })
    })
  })
})
