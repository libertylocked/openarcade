import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
import eutil from 'ethereumjs-util'
import { createCommit } from './helpers/randHelper'

const RandGen = artifacts.require('./RandGen.sol')

const [, alice, bob, carol, david] = web3.eth.accounts
const aliceNum = 42
const aliceCommit = createCommit(aliceNum)
const bobNum = 1337
const bobCommit = createCommit(bobNum)
const carolNum = 97
const carolCommit = createCommit(carolNum)

contract('RandGen', () => {
  let instance
  beforeEach('deploy a new RandGen contract', async () => {
    instance = await RandGen.new([alice, bob, carol])
  })
  describe('constructor', () => {
    it('should store the player count correctly if there is 2 players', async () => {
      const instance = await RandGen.new([alice, bob])
      assert.equal(await instance.playerCount(), 2)
    })
    it('should store the player count correctly if there is 10 players', async () => {
      assert.isAtLeast(web3.eth.accounts.length, 10, 'testrpc does not have at least 10 accounts')
      const instance = await RandGen.new(web3.eth.accounts.slice(0, 10))
      assert.equal(await instance.playerCount(), 10)
    })
    it('should set the starting state to commit', async () => {
      assert.equal(await instance.state(), 0)
    })
  })
  describe('commit', () => {
    it('should store the commit', async () => {
      const tx = await instance.commit(alice, aliceCommit)
      assert.equal(tx.logs[0].event, 'LogCommitted')
      assert.equal(tx.logs[0].args.player, alice)
      assert.equal(tx.logs[0].args.commit, aliceCommit)
      assert.equal(await instance.commits(alice), aliceCommit)
    })
    it('should not allow non player to commit', async () => {
      await assertRevert(instance.commit(david, 42))
    })
    it('should not allow multiple commits from same player', async () => {
      await instance.commit(alice, aliceCommit)
      await assertRevert(instance.commit(alice, aliceCommit))
    })
    it('should change state once all players have committed', async () => {
      await instance.commit(alice, aliceCommit)
      await instance.commit(bob, bobCommit)
      const tx = await instance.commit(carol, carolCommit)
      assert.equal(tx.logs.length, 2)
      assert.equal(tx.logs[1].event, 'LogStateChanged')
      assert.equal(tx.logs[1].args.state, 1)
      assert.equal(await instance.state(), 1)
    })
    // it('should allow non owner to directly commit', async () => {
    //   await instance.commit(0, aliceCommit, { from: alice })
    //   assert.equal(await instance.commits(alice), aliceCommit)
    // })
  })
  describe('reveal', () => {
    beforeEach('commit all the numbers from alice bob carol', async () => {
      await instance.commit(alice, aliceCommit)
      await instance.commit(bob, bobCommit)
      await instance.commit(carol, carolCommit)
    })
    it('should store the revealed number', async () => {
      assert.equal(await instance.state(), 1)
      const tx = await instance.reveal(alice, aliceNum)
      assert.equal(tx.logs[0].event, 'LogRevealed')
      assert.equal(tx.logs[0].args.player, alice)
      assert.equal(tx.logs[0].args.number, aliceNum)
      assert.equal(await instance.reveals(alice), aliceNum)
    })
    it('should not allow reveal before all committed', async () => {
      let rng = await RandGen.new([alice, bob])
      // only alice commit, bob does not
      await rng.commit(alice, aliceCommit)
      await assertRevert(rng.reveal(alice, aliceNum))
    })
    it('should not allow multiple reveals from same player', async () => {
      await instance.reveal(alice, aliceNum)
      await assertRevert(instance.reveal(alice, aliceNum))
    })
    it('should revert if number does not match commit', async () => {
      await assertRevert(instance.reveal(alice, aliceNum + 1))
    })
    it('should change state once all players have revealed', async () => {
      await instance.reveal(alice, aliceNum)
      await instance.reveal(bob, bobNum)
      const tx = await instance.reveal(carol, carolNum)
      assert.equal(tx.logs.length, 2)
      assert.equal(tx.logs[1].event, 'LogStateChanged')
      assert.equal(tx.logs[1].args.state, 2)
      assert.equal(await instance.state(), 2)
    })
    // it('should allow non owner to directly reveal', async () => {
    //   await instance.reveal(0, aliceNum, { from: alice })
    //   assert.equal(await instance.reveals(alice), aliceNum)
    // })
  })
  describe('next', () => {
    beforeEach('commit and reveal', async () => {
      await instance.commit(alice, aliceCommit)
      await instance.commit(bob, bobCommit)
      await instance.commit(carol, carolCommit)
      await instance.reveal(alice, aliceNum)
      await instance.reveal(bob, bobNum)
      await instance.reveal(carol, carolNum)
    })
    it('should revert if state is not set to done', async () => {
      const instance = await RandGen.new([alice, bob, carol])
      await assertRevert(instance.current())
      await assertRevert(instance.next())
    })
    it('should have the initial seed set to the xor of the numbers revealed', async () => {
      const xord = aliceNum ^ bobNum ^ carolNum
      assert.equal(await instance.index(), 0)
      assert.equal((await instance.seed()).toNumber(), xord)
    })
    it('should return the next random number', async () => {
      const nextNumHex = eutil.bufferToHex(eutil.keccak256(eutil.setLengthLeft(aliceNum ^ bobNum ^ carolNum, 32)))
      const tx = await instance.next()
      assert.equal(tx.logs[0].event, 'LogRandomGenerated')
      assert.equal(tx.logs[0].args.index, 1)
      assert.equal(`0x${tx.logs[0].args.number.toString(16)}`, nextNumHex)
      assert.equal(`0x${(await instance.current()).toString(16)}`, nextNumHex)
    })
    it('should return different numbers when calling next consecutively', async () => {
      const nextNumHex1 = eutil.bufferToHex(eutil.keccak256(eutil.setLengthLeft(aliceNum ^ bobNum ^ carolNum, 32)))
      const nextNumHex2 = eutil.bufferToHex(eutil.keccak256(nextNumHex1))
      const nextNumHex3 = eutil.bufferToHex(eutil.keccak256(nextNumHex2))
      await instance.next()
      assert.equal(`0x${(await instance.current()).toString(16)}`, nextNumHex1)
      await instance.next()
      assert.equal(`0x${(await instance.current()).toString(16)}`, nextNumHex2)
      await instance.next()
      assert.equal(`0x${(await instance.current()).toString(16)}`, nextNumHex3)
    })
  })
})
