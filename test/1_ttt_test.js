import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'
import XRandomJS from './helpers/xrandom'

// const Game = artifacts.require('TTTGame');
const Controller = artifacts.require('Controller')

// const newActionEncoder = (lib) => (...args) => lib.encodeAction.call(...args)
const encodeActionABI = (x, y) => eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'], [x, y]))
const newCommit = (v) => eutil.bufferToHex(XRandomJS.newCommit(v))
const encodeFixedUintArray = (arr) => eutil.bufferToHex(
  abi.rawEncode(arr.map(() => 'uint256'), arr))
const setupGame = async (controller, p1, p2) => {
  const bet = await controller.BET_AMOUNT()
  await controller.deposit({
    from: p1,
    value: bet
  })
  await controller.deposit({
    from: p2,
    value: bet
  })
  await controller.commit(newCommit(1337), { from: p1 })
  await controller.commit(newCommit(9001), { from: p2 })
  await controller.revealAndCommit(1337, newCommit(1338), { from: p1 })
  await controller.revealAndCommit(9001, newCommit(9002), { from: p2 })
  await controller.start(0)
}

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
      await controller.start(0)
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
      await controller.start(0)
      // the 1st number: sha3(1337 xor 9002) is
      // 0xd93d05651913279338de2ec0ab00dc6a13dc8c75c48a9de906cdc7712b825875
      // player 2 should go first
      assert.equal(await controller.control(), 2)
    })
  })
  describe('play', () => {
    beforeEach('setup game', async () => {
      await setupGame(controller, player1, player2)
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
      await setupGame(controller, player1, player2)
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
  describe('encode controller state', () => {
    beforeEach('setup game', async () => {
      await setupGame(controller, player1, player2)
    })
    it('should encode correctly when board is empty', async () => {
      const cstate = await controller.encodeControllerState.call()
      // player1 is in control. turn is 0. the board is empty
      assert.equal(cstate, encodeFixedUintArray([0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
    })
    it('should encode info and gamestate (1)', async () => {
      await controller.play(encodeAction(1, 1), { from: player1 })
      const cstate = await controller.encodeControllerState.call()
      // player2 is in control. turn is 1
      assert.equal(cstate, encodeFixedUintArray([1, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0]))
    })
    it('should encode info and gamestate (2)', async () => {
      await controller.play(encodeAction(1, 1), { from: player1 })
      await controller.play(encodeAction(1, 0), { from: player2 })
      const cstate = await controller.encodeControllerState.call()
      assert.equal(cstate, encodeFixedUintArray([2, 1, 0, 2, 0, 0, 1, 0, 0, 0, 0]))
    })
  })
  describe('request fastforward', () => {
    beforeEach('set up game', async () => {
      await setupGame(controller, player1, player2)
    })
    it('should allow players to vote to fastforward state', async () => {
      // create a state where player2 is in control, and (1, 1) is occupied by player 1
      const cstate = encodeFixedUintArray([1, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0])
      const cstateHash = eutil.bufferToHex(eutil.keccak256(cstate))
      // have both players sign the hash of cstate
      const p1Sig = eutil.fromRpcSig(web3.eth.sign(player1, cstateHash))
      const p2Sig = eutil.fromRpcSig(web3.eth.sign(player2, cstateHash))
      // players now request fastforward
      const tx = await controller.requestFastforward(cstate, [
        eutil.bufferToHex(p1Sig.r),
        eutil.bufferToHex(p2Sig.r)
      ], [
        eutil.bufferToHex(p1Sig.s),
        eutil.bufferToHex(p2Sig.s)
      ], [
        p1Sig.v,
        p2Sig.v
      ])
      assert.equal(tx.logs[0].event, 'LogStateFastforward')
      // check the control
      assert.equal(await controller.control.call(), 2)
      // game should not be in terminal state
      assert.isFalse(await controller.terminal.call())
      // check controller state
      const actualCstate = await controller.encodeControllerState.call()
      assert.equal(actualCstate, cstate)
    })
    it('should be playable after fastforwarding', async () => {
      // the state is after player 1 made the first move at (1,1)
      const cstate = encodeFixedUintArray([1, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0])
      const cstateHash = eutil.bufferToHex(eutil.keccak256(cstate))
      const p1Sig = eutil.fromRpcSig(web3.eth.sign(player1, cstateHash))
      const p2Sig = eutil.fromRpcSig(web3.eth.sign(player2, cstateHash))
      await controller.requestFastforward(cstate, [
        eutil.bufferToHex(p1Sig.r),
        eutil.bufferToHex(p2Sig.r)
      ], [
        eutil.bufferToHex(p1Sig.s),
        eutil.bufferToHex(p2Sig.s)
      ], [
        p1Sig.v,
        p2Sig.v
      ])
      // player 2 makes a move
      await controller.play(encodeAction(1, 0), { from: player2 })
      // then player 1 makes next move
      await controller.play(encodeAction(1, 2), { from: player1 })
    })
    it('should reject fastforward request if one of the sigs are not valid', async () => {
      const cstate = encodeFixedUintArray([1, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0])
      const cstateHash = eutil.bufferToHex(eutil.keccak256(cstate))
      // only player 1 signs the state
      const p1Sig = eutil.fromRpcSig(web3.eth.sign(player1, cstateHash))
      // now request fastforward with only 1 sig
      await assertRevert(controller.requestFastforward(cstate, [
        eutil.bufferToHex(p1Sig.r),
        '0x'
      ], [
        eutil.bufferToHex(p1Sig.s),
        '0x'
      ], [
        p1Sig.v,
        0
      ]))
    })
    it('should reject fastforward request if the target state is a previous state', async () => {
      await controller.play(encodeAction(1, 1), { from: player1 })
      await controller.play(encodeAction(1, 0), { from: player2 })
      // try to reset to initial state
      const cstate = encodeFixedUintArray([0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      const cstateHash = eutil.bufferToHex(eutil.keccak256(cstate))
      const p1Sig = eutil.fromRpcSig(web3.eth.sign(player1, cstateHash))
      const p2Sig = eutil.fromRpcSig(web3.eth.sign(player2, cstateHash))
      // players now request fastforward
      await assertRevert(controller.requestFastforward(cstate, [
        eutil.bufferToHex(p1Sig.r),
        eutil.bufferToHex(p2Sig.r)
      ], [
        eutil.bufferToHex(p1Sig.s),
        eutil.bufferToHex(p2Sig.s)
      ], [
        p1Sig.v,
        p2Sig.v
      ]))
    })
  })
})
