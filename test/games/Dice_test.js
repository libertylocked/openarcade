import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'

const TableRandom = artifacts.require('TableRandom')
const ConnectMock = artifacts.require('DiceConnectMock')

// In Dice game, action 1 means play, action 0 means give up
const encodeActionABI = (roll) => eutil.bufferToHex(abi.rawEncode(['uint256'], [roll]))

contract('Dice', (accounts) => {
  let connect
  let encodeAction
  before('get the encode action function', async () => {
    encodeAction = encodeActionABI
  })
  beforeEach('deploy a new ConnectMock', async () => {
    // create a table random
    // the first roll should be 1 (cause next skips first one as seed)
    const rng = await TableRandom.new([0, 1, 2, 3, 4, 5])
    connect = await ConnectMock.new(2, rng.address)
  })
  describe('init', () => {
    it('should set initial control to player 1', async () => {
      const tx = await connect.init(encodeActionABI(2))
      assert.equal(tx.logs[0].args.initialControl, 1)
    })
  })
  describe('next', () => {
    it('should alternate and wrap around', async () => {
      await connect.init(encodeActionABI(1))
      // 3 players, 1 is in control
      await connect.setInfo(3, 1)
      assert.equal((await connect.next()).toNumber(), 2)
      // make 2 in control
      await connect.setInfo(3, 2)
      assert.equal((await connect.next()).toNumber(), 3)
      // should wrap around
      await connect.setInfo(3, 3)
      assert.equal((await connect.next()).toNumber(), 1)
    })
  })
  describe('update', () => {
    it('should keep score correctly', async () => {
      // set 3 rounds
      await connect.init(encodeActionABI(3))
      // every update will roll 2 because next returns 1, game does %6+1 on it,
      // then requests new RNG so it gets reset
      await connect.update(1, encodeAction(1))
      await connect.update(2, encodeAction(1))
      await connect.update(1, encodeAction(1))
      await connect.update(2, encodeAction(1))
      await connect.update(1, encodeAction(1))
      await connect.update(2, encodeAction(1))
      assert.equal((await connect.goal(1)).toNumber(), 6)
      assert.equal((await connect.goal(2)).toNumber(), 6)
    })
    it('should keep score correctly (with RNG swap)', async () => {
      const rng1 = await TableRandom.new([1])
      const rng2 = await TableRandom.new([5])
      const connect = await ConnectMock.new(2, rng1.address)
      // only play 1 round this time
      await connect.init(encodeActionABI(1))
      await connect.update(1, encodeAction(1)) // roll 2
      // swap RNG
      await connect.setRandom(rng2.address)
      await connect.update(2, encodeAction(1)) // roll 6
      assert.equal((await connect.goal(1)).toNumber(), 2)
      assert.equal((await connect.goal(2)).toNumber(), 6)
    })
  })
  describe('legal', () => {
    it('should only allow player to play in his/her turn', async () => {
      // 2 players, 1 is in control
      await connect.setInfo(2, 1)
      assert.isTrue(await connect.legal(1, encodeActionABI(1)))
      assert.isFalse(await connect.legal(2, encodeActionABI(1)))
    })
  })
  describe('terminal', () => {
    it('should be terminal state if no rounds left', async () => {
      await connect.init(encodeActionABI(1))
      await connect.update(1, encodeActionABI(1))
      await connect.update(2, encodeActionABI(1))
      assert.isTrue(await connect.terminal())
    })
    it('should not be terminal state if there is rounds left', async () => {
      await connect.init(encodeActionABI(1))
      assert.isFalse(await connect.terminal())
    })
  })
  describe('goal', () => {
    it('should return the sum of rolls', async () => {
      await connect.init(encodeActionABI(1))
      await connect.update(1, encodeActionABI(1))
      await connect.update(2, encodeActionABI(1))
      assert.equal((await connect.goal(1)).toNumber(), 2)
      assert.equal((await connect.goal(2)).toNumber(), 2)
    })
  })
  describe('encode state', () => {
    it('should encode both rounds left and score array (1)', async () => {
      await connect.init(encodeActionABI(3))
      const expected = eutil.bufferToHex(
        abi.rawEncode(['uint256', 'uint256', 'uint256'], [3, 0, 0]))
      assert.equal(await connect.encodeState(), expected)
    })
    it('should encode both rounds left and score array (2)', async () => {
      await connect.init(encodeActionABI(3))
      await connect.update(1, encodeAction(1))
      const expected = eutil.bufferToHex(
        abi.rawEncode(['uint256', 'uint256', 'uint256'], [3, 2, 0]))
      assert.equal(await connect.encodeState(), expected)
    })
  })
  describe('set state', () => {
    it('should set the state correctly (1)', async () => {
      const encoded = eutil.bufferToHex(
        abi.rawEncode(['uint256', 'uint256', 'uint256'], [3, 2, 9]))
      await connect.setState(encoded)
      assert.equal((await connect.goal(1)).toNumber(), 2)
      assert.equal((await connect.goal(2)).toNumber(), 9)
      // roundtrip
      assert.equal(await connect.encodeState(), encoded)
    })
  })
})
