import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'
import XRandomJS from './helpers/xrandom'

const Controller = artifacts.require('DiceController')

const encodeActionABI = (roll) => eutil.bufferToHex(abi.rawEncode(['uint256'], [roll]))
const createCommit = (v) => eutil.bufferToHex(XRandomJS.createCommit(v))

contract('DiceGame', (accounts) => {
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
  describe('play and withdraw', () => {
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
      await controller.play(encodeAction(1), { from: player1 })
      await commitReveal(1337, 9001)
      await controller.play(encodeAction(1), { from: player2 })
      await commitReveal(1337, 9001)
      await controller.play(encodeAction(1), { from: player1 })
      await commitReveal(1337, 9001)
      await controller.play(encodeAction(1), { from: player2 })
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
      await controller.play(encodeAction(1), { from: player1 })
      await commitReveal(1337, 9001)
      await controller.play(encodeAction(1), { from: player2 })
      await assertRevert(controller.end())
      await assertRevert(controller.withdraw({ from: player1 }))
    })
  })
})
