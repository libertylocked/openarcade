import expectThrow from 'openzeppelin-solidity/test/helpers/expectThrow'
import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'
import { createCommit } from './helpers/randHelper'

const Controller = artifacts.require('./DiceController.sol')

const encodeActionABI = (roll) => eutil.bufferToHex(abi.rawEncode(['bool'], [roll]))

contract('DiceGame + Controller + Connect', (accounts) => {
  let controller
  let encodeAction
  const [, player1, player2] = accounts
  const commitReveal = async (num1, num2) => {
    await controller.commit(createCommit(num1), { from: player1 })
    await controller.commit(createCommit(num2), { from: player2 })
    await controller.reveal(num1, { from: player1 })
    await controller.reveal(num2, { from: player2 })
  }
  before('get the encode action function', async () => {
    encodeAction = encodeActionABI
  })
  beforeEach('deploy a new Controller', async () => {
    controller = await Controller.new([player1, player2])
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
      await commitReveal(1337, 9001)
      await controller.start()
    })
    it('should split the payout if match is a draw', async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.play(encodeAction(true), { from: player1 })
      await commitReveal(1337, 9001)
      await controller.play(encodeAction(true), { from: player2 })
      await commitReveal(1337, 9001)
      await controller.play(encodeAction(true), { from: player1 })
      await commitReveal(1337, 9001)
      await controller.play(encodeAction(true), { from: player2 })
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
      await controller.play(encodeAction(true), { from: player1 })
      await commitReveal(1337, 9001)
      await controller.play(encodeAction(true), { from: player2 })
      expectThrow(controller.end())
      expectThrow(controller.withdraw({ from: player1 }))
    })
  })
})
