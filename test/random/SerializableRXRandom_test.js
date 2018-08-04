import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
import eutil from 'ethereumjs-util'
import XRandomJS from '../helpers/xrandom'
import { encodeFixedUintArray } from '../helpers/encoding'

const SerializableRXRandom = artifacts.require('SerializableRXRandom')

const newCommit = (x) => eutil.bufferToHex(XRandomJS.newCommit(x))
const [owner, alice, bob, carol] = web3.eth.accounts

const aliceInput1 = 42
const aliceInput2 = 43
const aliceInput3 = 44
const bobInput1 = 1337
const bobInput2 = 1338
const carolInput1 = 9001
const carolInput2 = 9002

contract('SerializableRXRandom', () => {
  let instance
  beforeEach('deploy a new RXRandom contract', async () => {
    instance = await SerializableRXRandom.new([alice, bob, carol], owner)
  })
  describe('serialize', () => {
    describe('round -2', () => {
      it('should serialize correctly in initial state (round -2)', async () => {
        const expectedState = encodeFixedUintArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        assert.equal(await instance.serialize.call(), expectedState)
      })
      it('should serialize correctly when there is commit in round -2', async () => {
        const expectedState = encodeFixedUintArray([0, 0, 0, 0, 0, 1, 0,
          newCommit(aliceInput1), 0, 0])
        await instance.commit(alice, newCommit(aliceInput1))
        assert.equal(await instance.serialize.call(), expectedState)
      })
    })
    describe('round -1', () => {
      beforeEach('go from round -2 to round -1', async () => {
        await instance.commit(alice, newCommit(aliceInput1))
        await instance.commit(bob, newCommit(bobInput1))
        await instance.commit(carol, newCommit(carolInput1))
      })
      it('should serialize correctly at the beginning of round -1', async () => {
        const expectedState = encodeFixedUintArray([1, 0, 0, 0, 0, 3, 0,
          newCommit(aliceInput1), newCommit(bobInput1), newCommit(carolInput1)])
        assert.equal(await instance.serialize.call(), expectedState)
      })
      it('should serialize correctly when there is commit in round -1', async () => {
        // state 1, ringTurn 0, seed 42, current 42, index 0
        const expectedState = encodeFixedUintArray([1, 0, aliceInput1, aliceInput1, 0, 3, 1,
          newCommit(aliceInput2), newCommit(bobInput1), newCommit(carolInput1)])
        await instance.revealAndCommit(alice, aliceInput1, newCommit(aliceInput2))
        assert.equal(await instance.serialize.call(), expectedState)
      })
      it('should serialize correctly when there are commits in round -1', async () => {
        // state 1, ringTurn 0, seed 42^1337, current 42^1337, index 0
        const expectedSeed = new XRandomJS([aliceInput1, bobInput1]).seed.toNumber()
        const expectedState = encodeFixedUintArray([1, 0, expectedSeed, expectedSeed, 0, 3, 2,
          newCommit(aliceInput2), newCommit(bobInput2), newCommit(carolInput1)])
        await instance.revealAndCommit(alice, aliceInput1, newCommit(aliceInput2))
        await instance.revealAndCommit(bob, bobInput1, newCommit(bobInput2))
        assert.equal(await instance.serialize.call(), expectedState)
      })
    })
    describe('round 0+', () => {
      beforeEach('go from round -2 to round -1 to round 0', async () => {
        await instance.commit(alice, newCommit(aliceInput1))
        await instance.commit(bob, newCommit(bobInput1))
        await instance.commit(carol, newCommit(carolInput1))
        await instance.revealAndCommit(alice, aliceInput1, newCommit(aliceInput2))
        await instance.revealAndCommit(bob, bobInput1, newCommit(bobInput2))
        await instance.revealAndCommit(carol, carolInput1, newCommit(carolInput2))
      })
      it('should serialize correctly at beginning of round 0', async () => {
        const expectedSeed = new XRandomJS([aliceInput1, bobInput1, carolInput1]).seed.toNumber()
        const expectedState = encodeFixedUintArray([2, 0, expectedSeed, expectedSeed, 0, 3, 3,
          newCommit(aliceInput2), newCommit(bobInput2), newCommit(carolInput2)])
        assert.equal(await instance.serialize.call(), expectedState)
      })
      it('should serialize correctly when next is called', async () => {
        const rngJs = new XRandomJS([aliceInput1, bobInput1, carolInput1])
        const expectedSeed = `0x${rngJs.seed.toString(16)}`
        const expectedNext1 = `0x${rngJs.next().toString(16)}`
        const expectedState1 = encodeFixedUintArray([2, 0, expectedSeed, expectedNext1, 1, 3, 3,
          newCommit(aliceInput2), newCommit(bobInput2), newCommit(carolInput2)])
        await instance.next()
        assert.equal(await instance.serialize.call(), expectedState1)
        const expectedNext2 = `0x${rngJs.next().toString(16)}`
        const expectedState2 = encodeFixedUintArray([2, 0, expectedSeed, expectedNext2, 2, 3, 3,
          newCommit(aliceInput2), newCommit(bobInput2), newCommit(carolInput2)])
        await instance.next()
        assert.equal(await instance.serialize.call(), expectedState2)
      })
      it('should serialize correctly when request is called', async () => {
        const rngJs = new XRandomJS([aliceInput1, bobInput1, carolInput1])
        const expectedSeed1 = `0x${rngJs.seed.toString(16)}`
        const expectedNext1 = `0x${rngJs.next().toString(16)}`
        // state 3 (pending update), ringturn 0
        const expectedState1 = encodeFixedUintArray([3, 0, expectedSeed1, expectedNext1, 1, 3, 3,
          newCommit(aliceInput2), newCommit(bobInput2), newCommit(carolInput2)])
        await instance.next()
        await instance.request()
        assert.equal(await instance.serialize.call(), expectedState1)
        // resume RNG by revealAndCommit from alice
        await instance.revealAndCommit(alice, aliceInput2, newCommit(aliceInput3))
        rngJs.update([aliceInput2])
        const expectedSeed2 = `0x${rngJs.seed.toString(16)}`
        // the other expected state is when resumed
        // state 2 (ready), ringturn 1
        const expectedState2 = encodeFixedUintArray([2, 1, expectedSeed2, expectedSeed2, 0, 3, 3,
          newCommit(aliceInput3), newCommit(bobInput2), newCommit(carolInput2)])
        assert.equal(await instance.serialize.call(), expectedState2)
      })
    })
  })
  describe('deserialize', () => {
    describe('round -2', () => {
      it('should deserialize initial state in round -2', async () => {
        const encodedState = encodeFixedUintArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        await instance.deserializeByOwner(encodedState)
        // verify state
        assert.equal(await instance.state.call(), 0)
        assert.equal(await instance.roundNeg2CommitCount.call(), 0)
        assert.equal(await instance.roundNeg1CommitCount.call(), 0)
        // roundtrip
        assert.equal(await instance.serialize.call(), encodedState)
      })
      it('should deserialize correctly when there is commit in round -2', async () => {
        const encodedState = encodeFixedUintArray([0, 0, 0, 0, 0, 1, 0,
          newCommit(aliceInput1), 0, 0])
        await instance.deserializeByOwner(encodedState)
        // verify state
        assert.equal(await instance.state.call(), 0)
        assert.equal(await instance.roundNeg2CommitCount.call(), 1)
        assert.equal(await instance.roundNeg1CommitCount.call(), 0)
        assert.equal(await instance.commits.call(alice), newCommit(aliceInput1))
        // roundtrip
        assert.equal(await instance.serialize.call(), encodedState)
      })
      it('should reject if there are missing commits in encoded state', async () => {
        // have 1 missing commit
        const encodedState = encodeFixedUintArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
        await assertRevert(instance.deserializeByOwner(encodedState))
      })
    })
    describe('round -1', () => {
      beforeEach('go from round -2 to round -1', async () => {
        await instance.commit(alice, newCommit(aliceInput1))
        await instance.commit(bob, newCommit(bobInput1))
        await instance.commit(carol, newCommit(carolInput1))
      })
      it('should deserialize correctly at the beginning of round -1', async () => {
        const encodedState = encodeFixedUintArray([1, 0, 0, 0, 0, 3, 0,
          newCommit(aliceInput1), newCommit(bobInput1), newCommit(carolInput1)])
        // verify state
        assert.equal(await instance.state.call(), 1)
        assert.equal(await instance.roundNeg2CommitCount.call(), 3)
        assert.equal(await instance.roundNeg1CommitCount.call(), 0)
        assert.equal(await instance.commits.call(alice), newCommit(aliceInput1))
        assert.equal(await instance.commits.call(bob), newCommit(bobInput1))
        assert.equal(await instance.commits.call(carol), newCommit(carolInput1))
        // roundtrip
        assert.equal(await instance.serialize.call(), encodedState)
      })
      it('should deserialize correctly when there are commits in round -1', async () => {
        const seed = new XRandomJS([aliceInput1, bobInput1]).seed.toNumber()
        const encodedState = encodeFixedUintArray([1, 0, seed, seed, 0, 3, 2,
          newCommit(aliceInput2), newCommit(bobInput2), newCommit(carolInput1)])
        await instance.deserializeByOwner(encodedState)
        // verify state
        assert.equal(await instance.state.call(), 1)
        assert.equal(await instance.roundNeg2CommitCount.call(), 3)
        assert.equal(await instance.roundNeg1CommitCount.call(), 2)
        assert.equal(await instance.commits.call(alice), newCommit(aliceInput2))
        assert.equal(await instance.commits.call(bob), newCommit(bobInput2))
        assert.equal(await instance.commits.call(carol), newCommit(carolInput1))
        // roundtrip
        assert.equal(await instance.serialize.call(), encodedState)
        // advance to next state should still work
        await instance.revealAndCommit(carol, carolInput1, newCommit(carolInput2))
        assert.equal(await instance.state.call(), 2)
        assert.isTrue(await instance.ready.call())
      })
    })
    describe('round 0+', () => {
      beforeEach('go from round -2 to round -1 to round 0', async () => {
        await instance.commit(alice, newCommit(aliceInput1))
        await instance.commit(bob, newCommit(bobInput1))
        await instance.commit(carol, newCommit(carolInput1))
        await instance.revealAndCommit(alice, aliceInput1, newCommit(aliceInput2))
        await instance.revealAndCommit(bob, bobInput1, newCommit(bobInput2))
        await instance.revealAndCommit(carol, carolInput1, newCommit(carolInput2))
      })
      it('should deserialize correctly at the beginning of round 0', async () => {
        const seed = new XRandomJS([aliceInput1, bobInput1, carolInput1]).seed.toNumber()
        const encodedState = encodeFixedUintArray([2, 0, seed, seed, 0, 3, 3,
          newCommit(aliceInput2), newCommit(bobInput2), newCommit(carolInput2)])
        await instance.deserializeByOwner(encodedState)
        // verify state
        assert.equal(await instance.seed.call(), seed)
        assert.equal(await instance.state.call(), 2)
        assert.isTrue(await instance.ready.call())
        // roundtrip
        assert.equal(await instance.serialize.call(), encodedState)
      })
      it('should deserialize correctly when next is called', async () => {
        const rngJs = new XRandomJS([aliceInput1, bobInput1, carolInput1])
        const seed = `0x${rngJs.seed.toString(16)}`
        const current = `0x${rngJs.next().toString(16)}`
        const encodedState = encodeFixedUintArray([2, 0, seed, current, 1, 3, 3,
          newCommit(aliceInput2), newCommit(bobInput2), newCommit(carolInput2)])
        // set state
        await instance.deserializeByOwner(encodedState)
        // verify state
        assert.equal(await instance.state.call(), 2)
        assert.equal((await instance.seed.call()).toString(16), rngJs.seed.toString(16))
        assert.equal((await instance.current.call()).toString(16), rngJs.current.toString(16))
        assert.isTrue(await instance.ready.call())
        // roundtrip
        assert.equal(await instance.serialize.call(), encodedState)
      })
      it('should deserialize correctly when request is called', async () => {
        const rngJs = new XRandomJS([aliceInput1, bobInput1, carolInput1])
        const seed = `0x${rngJs.seed.toString(16)}`
        const current = `0x${rngJs.next().toString(16)}`
        // state 3 (pending update), ringturn 0
        const encodedState = encodeFixedUintArray([3, 0, seed, current, 1, 3, 3,
          newCommit(aliceInput2), newCommit(bobInput2), newCommit(carolInput2)])
        // restore state
        await instance.deserializeByOwner(encodedState)
        // verify state
        assert.equal(await instance.state.call(), 3)
        assert.isFalse(await instance.ready.call())
        // roundtrip
        assert.equal(await instance.serialize(), encodedState)
        // check if still works when resumed
        // resume RNG by revealAndCommit from alice
        await instance.revealAndCommit(alice, aliceInput2, newCommit(aliceInput3))
        rngJs.update([aliceInput2])
        // verify updated state
        assert.equal(await instance.state.call(), 2)
        assert.isTrue(await instance.ready.call())
        assert.equal(await instance.ringTurn.call(), 1)
        assert.equal((await instance.seed.call()).toString(16), rngJs.seed.toString(16))
        assert.equal(await instance.index.call(), 0)
      })
    })
  })
})
