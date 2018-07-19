import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
import eutil from 'ethereumjs-util'
import XRandomJS from './helpers/xrandom'

const RXRandom = artifacts.require('RXRandom')

const newCommit = (x) => eutil.bufferToHex(XRandomJS.newCommit(x))
const [owner, alice, bob, carol] = web3.eth.accounts

const aliceInput1 = 42
const aliceInput2 = 43
const bobInput1 = 1337
const bobInput2 = 1338
const carolInput1 = 9001
const carolInput2 = 9001

contract('RXRandom', () => {
  let instance
  beforeEach('deploy a new RXRandom contract', async () => {
    instance = await RXRandom.new([alice, bob, carol], owner)
  })
  describe('constructor', () => {
    it('should store the player count correctly if there is 2 players', async () => {
      const instance = await RXRandom.new([alice, bob], owner)
      assert.equal(await instance.playerCount(), 2)
    })
    it('should store the player count correctly if there is 10 players', async () => {
      assert.isAtLeast(web3.eth.accounts.length, 10, 'testrpc does not have at least 10 accounts')
      const instance = await RXRandom.new(web3.eth.accounts.slice(0, 10), owner)
      assert.equal(await instance.playerCount(), 10)
    })
    it('should set the starting state to RoundNeg2', async () => {
      assert.equal(await instance.state(), 0)
    })
  })
  describe('round neg 2 commit', () => {
    it('should allow commit in this round', async () => {
      const tx1 = await instance.commit(alice, newCommit(42))
      assert.equal(tx1.logs[0].event, 'LogCommitted')
      assert.equal(tx1.logs[0].args.player, alice)
      assert.equal(tx1.logs[0].args.commit, newCommit(42))
      await instance.commit(bob, newCommit(1337))
      await instance.commit(carol, newCommit(9001))
    })
    it('should not allow duplicate commits', async () => {
      await instance.commit(alice, newCommit(42))
      await assertRevert(instance.commit(alice, newCommit(44)))
    })
    it('should advance state once all players have committed', async () => {
      await instance.commit(alice, newCommit(42))
      await instance.commit(bob, newCommit(1337))
      await instance.commit(carol, newCommit(9001))
      assert.equal(await instance.state(), 1)
    })
  })
  describe('round neg 1 reveal and commit', () => {
    beforeEach('commit round neg 2', async () => {
      await instance.commit(alice, newCommit(aliceInput1))
      await instance.commit(bob, newCommit(bobInput1))
      await instance.commit(carol, newCommit(carolInput1))
    })
    it('should allow reveal in this round', async () => {
      const tx1 = await instance.revealAndCommit(alice, aliceInput1, newCommit(43))
      assert.equal(tx1.logs[0].event, 'LogRevealed')
      assert.equal(tx1.logs[0].args.player, alice)
      assert.equal(tx1.logs[0].args.input, aliceInput1)
      await instance.revealAndCommit(bob, bobInput1, newCommit(1338))
      await instance.revealAndCommit(carol, carolInput1, newCommit(9002))
    })
    it('should reject invalid reveals', async () => {
      await assertRevert(instance.revealAndCommit(alice, 99999, newCommit(43)))
    })
    it('should advance state once all players have revealed and committed', async () => {
      await instance.revealAndCommit(alice, aliceInput1, newCommit(43))
      await instance.revealAndCommit(bob, bobInput1, newCommit(1338))
      await instance.revealAndCommit(carol, carolInput1, newCommit(9002))
      // check state. should be set to ready
      assert.equal(await instance.state(), 2)
      // check RNG seed
      assert.equal((await instance.seed()).toString(16),
        new XRandomJS([aliceInput1, bobInput1, carolInput1]).seed.toString(16))
    })
  })
  describe('update', () => {
    beforeEach('advance to ready state', async () => {
      await instance.commit(alice, newCommit(aliceInput1))
      await instance.commit(bob, newCommit(bobInput1))
      await instance.commit(carol, newCommit(carolInput1))
      await instance.revealAndCommit(alice, aliceInput1, newCommit(aliceInput2))
      await instance.revealAndCommit(bob, bobInput1, newCommit(bobInput2))
      await instance.revealAndCommit(carol, carolInput1, newCommit(carolInput2))
    })
    it('should put the state to pending update once request is called', async () => {
      await instance.request()
      assert.equal(await instance.state(), 3)
    })
    it('should allow next player in ring to reveal and update when update is requested', async () => {
      await instance.request()
      await instance.revealAndCommit(alice, aliceInput2, newCommit(aliceInput2 + 1))
      // state should be back to ready
      assert.equal(await instance.state(), 2)
      // seed should be updated too
      const rng = new XRandomJS([aliceInput1, bobInput1, carolInput1])
      rng.update([aliceInput2])
      assert.equal((await instance.seed()).toString(16), rng.seed.toString(16))
      // ring turn should also be updated
      assert.equal(await instance.ringTurn(), 1)
    })
    it('should not allow out of order commits', async () => {
      await instance.request()
      await assertRevert(instance.revealAndCommit(bob, bobInput2, newCommit(bobInput2 + 1)))
    })
    it('should rotate ring turn correctly', async () => {
      await instance.request()
      await instance.revealAndCommit(alice, aliceInput2, newCommit(aliceInput2 + 1))
      await instance.request()
      await instance.revealAndCommit(bob, bobInput2, newCommit(bobInput2 + 1))
      await instance.request()
      await instance.revealAndCommit(carol, carolInput2, newCommit(carolInput2 + 1))
      await instance.request()
      await instance.revealAndCommit(alice, aliceInput2 + 1, newCommit(aliceInput2 + 2))
      // check seed updates
      const rng = new XRandomJS([aliceInput1, bobInput1, carolInput1])
      rng.update([aliceInput2, bobInput2, carolInput2, aliceInput2 + 1])
      assert.equal((await instance.seed()).toString(16), rng.seed.toString(16))
      // check ring turn
      assert.equal(await instance.ringTurn(), 4)
    })
  })
})
