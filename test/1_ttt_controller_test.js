import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
import advanceToBlock from 'openzeppelin-solidity/test/helpers/advanceToBlock'
import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'
import XRandomJS from './helpers/xrandom'
import { encodeFixedUintArray } from './helpers/encoding'

const Controller = artifacts.require('Controller')

// const newActionEncoder = (lib) => (...args) => lib.encodeAction.call(...args)
const encodeActionABI = (x, y) => eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'], [x, y]))
const newCommit = (v) => eutil.bufferToHex(XRandomJS.newCommit(v))
const getBetAmount = (controller) => controller.betAmount.call()
const getMinTimerDuration = (controller) => controller.minTimerDuration.call()
const setupGame = async (controller, p1, p2) => {
  const bet = await getBetAmount(controller)
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

contract('TTT Controller', (accounts) => {
  let controller
  let encodeAction
  const [, player1, player2] = accounts
  before('get the encode action function', async () => {
    // const gameLib = await Game.deployed()
    // encodeAction = newActionEncoder(gameLib)
    encodeAction = encodeActionABI
  })
  beforeEach('deploy a new Controller', async () => {
    controller = await Controller.new([player1, player2],
      web3.toWei(0.1, 'ether'), 5, 5)
  })
  describe('constructor', () => {
    it('should set player addresses and tunables correctly', async () => {
      const instance = await Controller.new([player1, player2],
        web3.toWei(0.5, 'ether'), 5, 5)
      assert.equal(await instance.players.call(player1), 1)
      assert.equal(await instance.players.call(player2), 2)
      assert.equal(await instance.betAmount.call(), web3.toWei(0.5, 'ether'), 5, 5)
      assert.equal(await instance.minTimerDuration.call(), 5)
      assert.equal(await instance.depositDuration.call(), 5)
    })
    it('should set timeout deadline correctly', async () => {
      const instance = await Controller.new([player1, player2],
        web3.toWei(0.1, 'ether'), 5, 5)
      const curBlock = web3.eth.blockNumber
      const deadline = await instance.depositDeadline.call()
      const depositDuration = await instance.depositDuration.call()
      assert.equal(deadline.toString(16), depositDuration.plus(curBlock).toString(16))
    })
  })
  describe('deposit', () => {
    it('should reject duplicate deposits', async () => {
      const bet = await getBetAmount(controller)
      await controller.deposit({ from: player1, value: bet })
      await assertRevert(controller.deposit({ from: player1, value: bet }))
    })
    it('should reject deposit whose value does not match bet amount', async () => {
      const bet = await getBetAmount(controller)
      await assertRevert(controller.deposit({ from: player1, value: bet.plus(1) }))
    })
  })
  describe('timeout during depositing', () => {
    it('should not allow withdraw before deposit timeout', async () => {
      const bet = await getBetAmount(controller)
      await controller.deposit({ from: player1, value: bet })
      await assertRevert(controller.cancelDeposit({ from: player1 }))
    })
    it('should allow withdraw if deposit timeouts', async () => {
      const bet = await getBetAmount(controller)
      const curBlock = web3.eth.blockNumber
      const depositDuration = await controller.depositDuration.call()
      await controller.deposit({ from: player1, value: bet })
      await advanceToBlock(depositDuration.plus(curBlock).toNumber())
      // call deposit timeout
      await controller.cancelDeposit({ from: player1 })
      assert.equal((await controller.lifecycle.call()).toNumber(), 3)
      // now player 1 should be able to withdraw
      await controller.withdraw({ from: player1 })
    })
  })
  describe('start', () => {
    beforeEach('deposit', async () => {
      const bet = await getBetAmount(controller)
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
      const tx = await controller.start(0)
      // the 1st number: sha3(1337 xor 9001) is
      // 0x4e66df4bdd547b751802471b8578ff25842645c69676a953cff51ab97f0006e6
      // player 1 should go first
      assert.equal(tx.logs[0].event, 'LogGameStart')
      assert.equal(tx.logs[0].args.control, 1)
      assert.equal(await controller.control(), 1)
    })
    it('should let player 2 go first if random number is odd', async () => {
      await controller.commit(newCommit(1337), { from: player1 })
      await controller.commit(newCommit(9002), { from: player2 })
      await controller.revealAndCommit(1337, newCommit(1338), { from: player1 })
      await controller.revealAndCommit(9002, newCommit(9002), { from: player2 })
      const tx = await controller.start(0)
      // the 1st number: sha3(1337 xor 9002) is
      // 0xd93d05651913279338de2ec0ab00dc6a13dc8c75c48a9de906cdc7712b825875
      // player 2 should go first
      assert.equal(tx.logs[0].event, 'LogGameStart')
      assert.equal(tx.logs[0].args.control, 2)
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
      const bet = await getBetAmount(controller)
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
      const bet = await getBetAmount(controller)
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
  describe('serialize', () => {
    it('should encode correctly when board is empty', async () => {
      await setupGame(controller, player1, player2)
      // player1 is in control. turn is 1. the board is empty
      const rng = new XRandomJS([1337, 9001])
      // state index is 3 cause turn 1 and RNG ready
      assert.equal(await controller.serialize.call(), encodeFixedUintArray([3, 1,
        2, 0, `0x${rng.seed.toString(16)}`, `0x${rng.next().toString(16)}`, 1, 2, 2,
        newCommit(1338), newCommit(9002),
        0, 0, 0, 0, 0, 0, 0, 0, 0]))
    })
    it('should encode info and gamestate during playing state (1)', async () => {
      await setupGame(controller, player1, player2)
      await controller.play(encodeAction(1, 1), { from: player1 })
      // player2 is in control. turn is 2
      const rng = new XRandomJS([1337, 9001])
      // state index is 5 cause turn 2 and RNG ready
      assert.equal(await controller.serialize.call(), encodeFixedUintArray([5, 2,
        2, 0, `0x${rng.seed.toString(16)}`, `0x${rng.next().toString(16)}`, 1, 2, 2,
        newCommit(1338), newCommit(9002),
        0, 0, 0, 0, 1, 0, 0, 0, 0]))
    })
    it('should encode info and gamestate during playing state (2)', async () => {
      await setupGame(controller, player1, player2)
      await controller.play(encodeAction(1, 1), { from: player1 })
      await controller.play(encodeAction(1, 0), { from: player2 })
      const rng = new XRandomJS([1337, 9001])
      // state index is 7 cause turn 3 and RNG ready
      assert.equal(await controller.serialize.call(), encodeFixedUintArray([7, 1,
        2, 0, `0x${rng.seed.toString(16)}`, `0x${rng.next().toString(16)}`, 1, 2, 2,
        newCommit(1338), newCommit(9002),
        0, 2, 0, 0, 1, 0, 0, 0, 0]))
    })
  })
  describe('request fastforward', () => {
    it('should allow players to vote to fastforward from starting to playing', async () => {
      // only deposit but not set up RNG or call start yet
      const bet = await getBetAmount(controller)
      await controller.deposit({ from: player1, value: bet })
      await controller.deposit({ from: player2, value: bet })
      // fastforward to a state after player 1 has made the first move at (1, 1)
      const rng = new XRandomJS([1337, 9001])
      // stateIndex is 5, cause it is turn 2 and RNG is ready
      const cstate = encodeFixedUintArray([5, 2,
        2, 0, `0x${rng.seed.toString(16)}`, `0x${rng.next().toString(16)}`, 1, 2, 2,
        newCommit(1338), newCommit(9002),
        0, 0, 0, 0, 1, 0, 0, 0, 0])
      // sign the hash of cstate
      const cstateHash = eutil.bufferToHex(eutil.keccak256(cstate))
      const p1Sig = eutil.fromRpcSig(web3.eth.sign(player1, cstateHash))
      const p2Sig = eutil.fromRpcSig(web3.eth.sign(player2, cstateHash))
      // fastforward from starting to playing
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
      assert.equal(tx.logs[0].args.turn, 2)
      // verify state
      assert.equal(await controller.control.call(), 2)
      assert.isFalse(await controller.terminal.call())
      // roundtrip
      assert.equal(await controller.serialize.call(), cstate)
    })
    it('should allow players to vote to fastforward from playing to playing', async () => {
      await setupGame(controller, player1, player2)
      // create a state where player2 is in control, and (1, 1) is occupied by player 1
      const rng = new XRandomJS([1337, 9001])
      // state index is 5 cause turn 2 and RNG ready
      const cstate = encodeFixedUintArray([5, 2,
        2, 0, `0x${rng.seed.toString(16)}`, `0x${rng.next().toString(16)}`, 1, 2, 2,
        newCommit(1338), newCommit(9002),
        0, 0, 0, 0, 1, 0, 0, 0, 0])
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
      // verify state
      assert.equal(await controller.control.call(), 2)
      assert.isFalse(await controller.terminal.call())
      // roundtrip
      const actualCstate = await controller.serialize.call()
      assert.equal(actualCstate, cstate)
    })
    it('should be playable after fastforwarding from playing to playing', async () => {
      await setupGame(controller, player1, player2)
      // the state is after player 1 made the first move at (1,1)
      const rng = new XRandomJS([1337, 9001])
      // state index is 5 cause turn 2 and RNG ready
      const cstate = encodeFixedUintArray([5, 2,
        2, 0, `0x${rng.seed.toString(16)}`, `0x${rng.next().toString(16)}`, 1, 2, 2,
        newCommit(1338), newCommit(9002),
        0, 0, 0, 0, 1, 0, 0, 0, 0])
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
      await setupGame(controller, player1, player2)
      const rng = new XRandomJS([1337, 9001])
      const cstate = encodeFixedUintArray([5, 2,
        2, 0, `0x${rng.seed.toString(16)}`, `0x${rng.next().toString(16)}`, 1, 2, 2,
        newCommit(1338), newCommit(9002),
        0, 0, 0, 0, 1, 0, 0, 0, 0])
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
    it('should reject fastforward request if the target state index has already been fastforwarded', async () => {
      await setupGame(controller, player1, player2)
      const rng = new XRandomJS([1337, 9001])
      // first set state to state index 7 (turn 3, RNG ready)
      const cstate = encodeFixedUintArray([7, 2,
        2, 0, `0x${rng.seed.toString(16)}`, `0x${rng.next().toString(16)}`, 1, 2, 2,
        newCommit(1338), newCommit(9002),
        0, 0, 2, 0, 1, 0, 0, 0, 0])
      const cstateHash = eutil.bufferToHex(eutil.keccak256(cstate))
      const p1Sig = eutil.fromRpcSig(web3.eth.sign(player1, cstateHash))
      const p2Sig = eutil.fromRpcSig(web3.eth.sign(player2, cstateHash))
      // players now request fastforward to set the state
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
      // now try to FF backward to state index 5
      const cstate2 = encodeFixedUintArray([5, 2,
        2, 0, `0x${rng.seed.toString(16)}`, `0x${rng.next().toString(16)}`, 1, 2, 2,
        newCommit(1338), newCommit(9002),
        0, 0, 0, 0, 1, 0, 0, 0, 0])
      const cstateHash2 = eutil.bufferToHex(eutil.keccak256(cstate2))
      const p1Sig2 = eutil.fromRpcSig(web3.eth.sign(player1, cstateHash2))
      const p2Sig2 = eutil.fromRpcSig(web3.eth.sign(player2, cstateHash2))
      // players now request fastforward to set the state
      await assertRevert(controller.requestFastforward(cstate2, [
        eutil.bufferToHex(p1Sig2.r),
        eutil.bufferToHex(p2Sig2.r)
      ], [
        eutil.bufferToHex(p1Sig2.s),
        eutil.bufferToHex(p2Sig2.s)
      ], [
        p1Sig2.v,
        p2Sig2.v
      ]))
    })
  })
  describe('timeout during starting', () => {
    it('should refund all players if timeout during starting', async () => {
      const bet = await getBetAmount(controller)
      // only deposit but do not set up RNG
      await controller.deposit({ from: player1, value: bet })
      await controller.deposit({ from: player2, value: bet })
      // now advance blocks to timeout
      await advanceToBlock((await controller.depositDeadline.call()).toNumber())
      await controller.cancelDeposit()
      // check state
      assert.equal((await controller.lifecycle.call()).toNumber(), 3)
      // now withdraw
      const tx1 = await controller.withdraw({ from: player1 })
      assert.equal(tx1.logs[0].event, 'LogWithdraw')
      assert.equal(tx1.logs[0].args.player, player1)
      assert.equal(tx1.logs[0].args.amount.toString(16), bet.toString(16))
      const tx2 = await controller.withdraw({ from: player2 })
      assert.equal(tx2.logs[0].event, 'LogWithdraw')
      assert.equal(tx2.logs[0].args.player, player2)
      assert.equal(tx2.logs[0].args.amount.toString(16), bet.toString(16))
    })
  })
  describe('timeout during playing', () => {
    describe('start timer', () => {
      it('should allow start timer in initial playing state', async () => {
        await setupGame(controller, player1, player2)
        const minDuration = await getMinTimerDuration(controller)
        const tx = await controller.startTimer(minDuration, { from: player1 })
        // starting control is random, but in our example it should be player1
        assert.equal(tx.logs[0].event, 'LogTimerStarted')
        assert.equal(tx.logs[0].args.turn, 1)
        assert.isTrue(tx.logs[0].args.rngReady)
        assert.equal(tx.logs[0].args.deadline.toString(16),
          minDuration.plus(tx.receipt.blockNumber).toString(16))
        // verify state
        assert.isTrue(await controller.timerStarted.call())
        assert.equal((await controller.timeoutDeadline.call()).toString(16),
          minDuration.plus(tx.receipt.blockNumber).toString(16))
      })
      it('should not allow starting timer too short', async () => {
        await setupGame(controller, player1, player2)
        await assertRevert(controller.startTimer(1, { from: player1 }))
      })
      it('should not allow starting timer in terminal state', async () => {
        await setupGame(controller, player1, player2)
        await controller.play(encodeAction(1, 1), { from: player1 })
        await controller.play(encodeAction(1, 0), { from: player2 })
        await controller.play(encodeAction(0, 0), { from: player1 })
        await controller.play(encodeAction(2, 2), { from: player2 })
        await controller.play(encodeAction(2, 0), { from: player1 })
        await controller.play(encodeAction(0, 2), { from: player2 })
        await controller.play(encodeAction(1, 2), { from: player1 })
        await controller.play(encodeAction(0, 1), { from: player2 })
        await controller.play(encodeAction(2, 1), { from: player1 })
        // board is now full, but no one is winnng
        const minDuration = await getMinTimerDuration(controller)
        await assertRevert(controller.startTimer(minDuration, { from: player1 }))
      })
      it('should not allow starting timer in starting state', async () => {
        const bet = await getBetAmount(controller)
        await controller.deposit({ from: player1, value: bet })
        await controller.deposit({ from: player2, value: bet })
        const minDuration = await getMinTimerDuration(controller)
        // now the game is in starting state
        // start timeout should fail
        await assertRevert(controller.startTimer(minDuration, { from: player1 }))
      })
    })
    describe('timeout', () => {
      it('should end the game if control player misses deadline', async () => {
        await setupGame(controller, player1, player2)
        const minDuration = await getMinTimerDuration(controller)
        const betAmount = await getBetAmount(controller)
        await controller.startTimer(minDuration, { from: player2 })
        await advanceToBlock(minDuration.plus(web3.eth.blockNumber))
        await controller.timeout({ from: player2 })
        const tx = await controller.withdraw({ from: player2 })
        assert.equal(tx.logs[0].event, 'LogWithdraw')
        assert.equal(tx.logs[0].args.player, player2)
        assert.equal(tx.logs[0].args.amount.toString(16), betAmount.mul(2).toString(16))
      })
      it('should not allow timeout before deadline', async () => {
        await setupGame(controller, player1, player2)
        const minDuration = await getMinTimerDuration(controller)
        await controller.startTimer(minDuration, { from: player2 })
        // immediately try calling timeout
        await assertRevert(controller.timeout({ from: player2 }))
      })
    })
    describe('stop timer', () => {
      it('should stop timer after fastforward', async () => {
        await setupGame(controller, player1, player2)
        const minDuration = await getMinTimerDuration(controller)
        await controller.startTimer(minDuration, { from: player2 })
        // now Fastforward to a future state
        const rng = new XRandomJS([1337, 9001])
        const cstate = encodeFixedUintArray([7, 2,
          2, 0, `0x${rng.seed.toString(16)}`, `0x${rng.next().toString(16)}`, 1, 2, 2,
          newCommit(1338), newCommit(9002),
          0, 0, 2, 0, 1, 0, 0, 0, 0])
        const cstateHash = eutil.bufferToHex(eutil.keccak256(cstate))
        const p1Sig = eutil.fromRpcSig(web3.eth.sign(player1, cstateHash))
        const p2Sig = eutil.fromRpcSig(web3.eth.sign(player2, cstateHash))
        // players now request fastforward to set the state
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
        // timer should stop
        assert.isFalse(await controller.timerStarted.call())
      })
    })
  })
})
