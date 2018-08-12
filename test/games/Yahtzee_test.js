import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'
import { encodeFixedUintArray } from '../helpers/encoding'

const TableRandom = artifacts.require('TableRandom')
const ConnectMock = artifacts.require('YahtzeeConnectMock')

const encodeActionABI = (r1, r2, r3, r4, r5, comboPick) =>
  eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'],
    [r1 | r2 << 1 | r3 << 2 | r4 << 3 | r5 << 4, comboPick]))

contract('Yahtzee', (accounts) => {
  let connect
  beforeEach('deploy a new ConnectMock', async () => {
    // create a table random
    // the first next should be 1 (cause next skips first one as seed)
    const rng = await TableRandom.new([0, 1, 2, 3, 4, 5])
    connect = await ConnectMock.new(2, rng.address)
    await connect.init(0)
  })
  describe('init', () => {
    it('should set initial control to player 1', async () => {
      const tx = await connect.init(0)
      assert.equal(tx.logs[0].args.initialControl, 1)
    })
  })
  describe('next', () => {
    it('should not alternate until all rolls are used', async () => {
      assert.equal((await connect.next()).toNumber(), 1)
    })
    it('should alternate once combo is picked', async () => {
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0)) // not reroll
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 10)) // pick large straight
      assert.equal((await connect.next.call()).toNumber(), 2)
    })
  })
  describe('update', () => {
    it('should update both players scores', async () => {
      await connect.update(1, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 1
      await connect.update(1, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 2
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 1)) // pick Twos combo
      assert.equal((await connect.goal.call(1)).toNumber(), 2)
      assert.equal((await connect.next.call()).toNumber(), 2)
      await connect.setInfo(2, 2, 2)
      assert.isTrue(await connect.legal.call(2, encodeActionABI(1, 1, 1, 1, 1, 0)))
      // now player 2 plays
      await connect.update(2, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 1
      await connect.update(2, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 2
      await connect.update(2, encodeActionABI(0, 0, 0, 0, 0, 10)) // pick large straight
      assert.equal((await connect.goal.call(2)).toNumber(), 40)
      assert.equal((await connect.next.call()).toNumber(), 1)
    })
  })
  describe('legal', () => {
    it('should not allow out of turn plays', async () => {
      assert.isFalse((await connect.legal.call(2,
        encodeActionABI(1, 1, 1, 1, 1, 0))))
    })
    it('should not allow overflown roll picks', async () => {
      assert.isFalse((await connect.legal.call(1,
        encodeFixedUintArray([32, 0]))))
    })
    it('should only allow zero roll pick if out of rolls', async () => {
      await connect.update(1, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 1
      await connect.update(1, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 2
      assert.isFalse((await connect.legal.call(1,
        encodeFixedUintArray([31, 0]))))
    })
    it('should not allow picking a combo thats already used', async () => {
      await connect.update(1, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 1
      await connect.update(1, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 2
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 1)) // pick Twos combo
      // skip player 2 turn by putting control back to player 1
      await connect.setInfo(2, 3, 1)
      await connect.update(1, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 1
      await connect.update(1, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 2
      assert.isFalse((await connect.legal.call(1,
        encodeFixedUintArray([0, 1]))))
    })
  })
  describe('terminal', () => {
    it('should return true if all combos are used', async () => {
      const rng = await TableRandom.new([0, 1, 2, 3, 4, 5])
      await connect.setRandom(rng.address)
      for (let i = 0; i < 13; ++i) {
        assert.isFalse((await connect.terminal.call()))
        await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
        await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, i))
        assert.isFalse((await connect.terminal.call()))
        await connect.update(2, encodeActionABI(0, 0, 0, 0, 0, 0))
        await connect.update(2, encodeActionABI(0, 0, 0, 0, 0, i))
      }
      assert.isTrue((await connect.terminal.call()))
    })
  })
  describe('goal', () => {
    it('should return correct score for Ones', async () => {
      const rng = await TableRandom.new([0, 0, 0, 0, 0, 0])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0)) // not reroll
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0)) // pick Ones
      assert.equal((await connect.goal.call(1)).toNumber(), 5)
    })
    it('should return correct score for Twos', async () => {
      const rng = await TableRandom.new([0, 1, 1, 0, 0, 0])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 1))
      assert.equal((await connect.goal.call(1)).toNumber(), 4)
    })
    it('should return correct score for Threes', async () => {
      const rng = await TableRandom.new([0, 0, 0, 2, 2, 2])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 2))
      assert.equal((await connect.goal.call(1)).toNumber(), 9)
    })
    it('should return correct score for Fours', async () => {
      const rng = await TableRandom.new([0, 0, 0, 0, 3, 3])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 3))
      assert.equal((await connect.goal.call(1)).toNumber(), 8)
    })
    it('should return correct score for Fives', async () => {
      const rng = await TableRandom.new([0, 0, 0, 4, 0, 4])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 4))
      assert.equal((await connect.goal.call(1)).toNumber(), 10)
    })
    it('should return correct score for Sixes', async () => {
      const rng = await TableRandom.new([0, 3, 4, 5, 5, 3])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 5))
      assert.equal((await connect.goal.call(1)).toNumber(), 12)
    })
    it('should return correct score for Three of a kind (1)', async () => {
      // roll is [1 2 3 3 3]
      const rng = await TableRandom.new([0, 0, 1, 2, 2, 2])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 6))
      // score is sum of all dice
      assert.equal((await connect.goal.call(1)).toNumber(), 12)
    })
    it('should return correct score for Three of a kind (2)', async () => {
      const rng = await TableRandom.new([0, 0, 1, 2, 3, 4])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 6))
      // no three of a kind
      assert.equal((await connect.goal.call(1)).toNumber(), 0)
    })
    it('should return correct score for Four of a kind', async () => {
      // roll is [1 3 3 3 3]
      const rng = await TableRandom.new([0, 0, 2, 2, 2, 2])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 7))
      // score is sum of all dice
      assert.equal((await connect.goal.call(1)).toNumber(), 13)
    })
    it('should return correct score for Full house (1)', async () => {
      // roll is [3 3 5 5 5]
      const rng = await TableRandom.new([0, 2, 2, 4, 4, 4])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 8))
      assert.equal((await connect.goal.call(1)).toNumber(), 25)
    })
    it('should return correct score for Full house (2)', async () => {
      const rng = await TableRandom.new([0, 2, 2, 3, 4, 5])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 8))
      assert.equal((await connect.goal.call(1)).toNumber(), 0)
    })
    it('should return correct score for Small straight (1)', async () => {
      // roll is [6 2 3 1 4]
      const rng = await TableRandom.new([0, 5, 1, 2, 0, 3])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 9))
      assert.equal((await connect.goal.call(1)).toNumber(), 30)
    })
    it('should return correct score for Small straight (2)', async () => {
      // roll is [6 1 1 3 2]
      const rng = await TableRandom.new([0, 5, 0, 0, 2, 1])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 9))
      assert.equal((await connect.goal.call(1)).toNumber(), 0)
    })
    it('should return correct score for Large straight (1)', async () => {
      // roll is [5 2 3 1 4]
      const rng = await TableRandom.new([0, 4, 1, 2, 0, 3])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 10))
      assert.equal((await connect.goal.call(1)).toNumber(), 40)
    })
    it('should return correct score for Large straight (2)', async () => {
      // roll is [6 1 4 3 2]
      const rng = await TableRandom.new([0, 5, 0, 3, 2, 1])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 10))
      assert.equal((await connect.goal.call(1)).toNumber(), 0)
    })
    it('should return correct score for Chance', async () => {
      // roll is [1 5 6 5 1]
      const rng = await TableRandom.new([0, 0, 4, 5, 4, 0])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 11))
      assert.equal((await connect.goal.call(1)).toNumber(), 18)
    })
    it('should return correct score for Yahtzee', async () => {
      // roll is [5 5 5 5 5]
      const rng = await TableRandom.new([0, 4, 4, 4, 4, 4])
      await connect.setRandom(rng.address)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0))
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 12))
      assert.equal((await connect.goal.call(1)).toNumber(), 50)
    })
  })
  describe('encode state', () => {
    it('should initial state correctly', async () => {
      // [scoreCard, pickedCombos, rollsLeft, rollPick, dices]
      const expected = encodeFixedUintArray([26]
        .concat(Array(52).fill(0))
        .concat([3, 31, 0, 0, 0, 0, 0, 1]))
      assert.equal(await connect.encodeState(), expected)
    })
    it('should encode the roll pick after play', async () => {
      await connect.update(1, encodeActionABI(0, 1, 1, 1, 1, 0))
      const expected = encodeFixedUintArray([26]
        .concat(Array(52).fill(0))
        .concat([2, 30, 2, 3, 4, 5, 6, 1]))
      assert.equal(await connect.encodeState(), expected)
    })
    it('should encode score card after picking a combo', async () => {
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0)) // not reroll
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 10)) // pick large straight
      const expected = encodeFixedUintArray([26]
        .concat([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 40, 0, 0]).concat(Array(13).fill(0))
        .concat([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0]).concat(Array(13).fill(0))
        .concat([3, 31, 2, 3, 4, 5, 6, 2]))
      assert.equal(await connect.encodeState(), expected)
    })
  })
  describe('set state', () => {
    it('should set the state correctly to just after picking a combo', async () => {
      const encodedState = encodeFixedUintArray([26]
        .concat([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 40, 0, 0]).concat(Array(13).fill(0))
        .concat([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0]).concat(Array(13).fill(0))
        .concat([0, 0, 2, 3, 4, 5, 6, 2]))
      await connect.setState(encodedState)
      assert.equal((await connect.next.call()).toNumber(), 2)
    })
  })
})
