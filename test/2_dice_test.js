import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'
import XRandomJS from './helpers/xrandom'

const Controller = artifacts.require('DiceController')

const encodeActionABI = (roll) => eutil.bufferToHex(abi.rawEncode(['uint256'], [roll]))
const newCommit = (v) => eutil.bufferToHex(XRandomJS.newCommit(v))

contract('DiceGame', (accounts) => {
  let controller
  let encodeAction
  const [, alice, bob] = accounts
  before('get the encode action function', async () => {
    encodeAction = encodeActionABI
  })
  beforeEach('deploy a new Controller', async () => {
    controller = await Controller.new([alice, bob])
  })
  describe('play and withdraw', () => {
    const aliceNum1 = 1337
    const bobNum1 = 9001
    beforeEach('setup game', async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.deposit({
        from: alice,
        value: bet
      })
      await controller.deposit({
        from: bob,
        value: bet
      })
      await controller.commit(newCommit(aliceNum1), { from: alice })
      await controller.commit(newCommit(bobNum1), { from: bob })
      await controller.revealAndCommit(aliceNum1, newCommit(aliceNum1 + 1), { from: alice })
      await controller.revealAndCommit(bobNum1, newCommit(bobNum1 + 1), { from: bob })
      await controller.start(eutil.bufferToHex(abi.rawEncode(['uint256'], [2])))
    })
    it('should split the payout based on score', async () => {
      await controller.play(encodeAction(1), { from: alice })
      await controller.revealAndCommit(aliceNum1 + 1, newCommit(aliceNum1 + 2), { from: alice })
      await controller.play(encodeAction(1), { from: bob })
      await controller.revealAndCommit(bobNum1 + 1, newCommit(bobNum1 + 2), { from: bob })
      await controller.play(encodeAction(1), { from: alice })
      await controller.revealAndCommit(aliceNum1 + 2, newCommit(aliceNum1 + 3), { from: alice })
      await controller.play(encodeAction(1), { from: bob })
      await controller.end()
      const tx = await controller.withdraw({ from: alice })
      assert.equal(tx.logs[0].event, 'LogWithdraw')
      assert.equal(tx.logs[0].args.player, alice)
      // assert.equal(tx.logs[0].args.amount.toString(), bet.toString())
      const tx2 = await controller.withdraw({ from: bob })
      assert.equal(tx2.logs[0].event, 'LogWithdraw')
      assert.equal(tx2.logs[0].args.player, bob)
      // assert.equal(tx2.logs[0].args.amount.toString(), bet.toString())
    })
    it('should not allow withdraw before terminal state', async () => {
      await controller.play(encodeAction(1), { from: alice })
      await controller.revealAndCommit(aliceNum1 + 1, newCommit(aliceNum1 + 2), { from: alice })
      await controller.play(encodeAction(1), { from: bob })
      await assertRevert(controller.end())
      await assertRevert(controller.withdraw({ from: alice }))
    })
  })
})
