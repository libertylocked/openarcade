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
  })
  describe('init', () => {
    it('should set initial control to player 1', async () => {
      const tx = await connect.init(0)
      assert.equal(tx.logs[0].args.initialControl, 1)
    })
  })
  describe('next', () => {
    it('should not alternate until all rolls are used', async () => {
      await connect.init(0)
      assert.equal((await connect.next()).toNumber(), 1)
    })
    it('should alternate once combo is picked', async () => {
      await connect.init(0)
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 0)) // not reroll
      await connect.update(1, encodeActionABI(0, 0, 0, 0, 0, 10)) // pick large straight
      assert.equal((await connect.next.call()).toNumber(), 2)
    })
  })
  describe('update', () => {
    it('should update both players scores', async () => {
      await connect.init(0)
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
      await connect.init(0)
      assert.isFalse((await connect.legal.call(2,
        encodeActionABI(1, 1, 1, 1, 1, 0))))
    })
    it('should not allow overflown roll picks', async () => {
      await connect.init(0)
      assert.isFalse((await connect.legal.call(1,
        encodeFixedUintArray([32, 0]))))
    })
    it('should only allow zero roll pick if out of rolls', async () => {
      await connect.init(0)
      await connect.update(1, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 1
      await connect.update(1, encodeActionABI(1, 1, 1, 1, 1, 0)) // reroll 2
      assert.isFalse((await connect.legal.call(1,
        encodeFixedUintArray([31, 0]))))
    })
    it('should not allow picking a combo thats already used', async () => {
      await connect.init(0)
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
  })
  describe('goal', () => {
    it('should return the score card sum', async () => {
    })
  })
  describe('encode state', () => {
    it('should initial state correctly', async () => {
      await connect.init(0)
      // [scoreCard, pickedCombos, rollsLeft, rollPick, dices]
      const expected = encodeFixedUintArray([26]
        .concat(Array(52).fill(0))
        .concat([3, 31, 0, 0, 0, 0, 0, 1]))
      assert.equal(await connect.encodeState(), expected)
    })
    it('should encode the roll pick after play', async () => {
      await connect.init(0)
      await connect.update(1, encodeActionABI(0, 1, 1, 1, 1, 0))
      const expected = encodeFixedUintArray([26]
        .concat(Array(52).fill(0))
        .concat([2, 30, 2, 3, 4, 5, 6, 1]))
      assert.equal(await connect.encodeState(), expected)
    })
    it('should encode score card after picking a combo', async () => {
      await connect.init(0)
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
      await connect.init(0)
      await connect.setState(encodedState)
      assert.equal((await connect.next.call()).toNumber(), 2)
    })
  })
})
