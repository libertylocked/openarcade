import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'

const TableRandom = artifacts.require('TableRandom')
const ConnectMock = artifacts.require('ConnectMock')

const encodeActionABI = (x, y) => eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'], [x, y]))
const encodeFixedUintArray = (arr) => eutil.bufferToHex(
  abi.rawEncode(arr.map(() => 'uint256'), arr))

contract('TTT', (accounts) => {
  let connect
  let encodeAction
  before('get the encode action function', async () => {
    encodeAction = encodeActionABI
  })
  beforeEach('deploy a new ConnectMock', async () => {
    const rng = await TableRandom.new([0])
    connect = await ConnectMock.new(2, rng.address)
  })
  describe('init', () => {
    it('should set initial control to player 1 if RNG next is 0', async () => {
      const rng = await TableRandom.new([0])
      const connect = await ConnectMock.new(2, rng.address)
      const tx = await connect.init('0x')
      assert.equal(tx.logs[0].args.initialControl, 1)
    })
    it('should set initial control to player 2 if RNG next is 1', async () => {
      const rng = await TableRandom.new([1])
      const connect = await ConnectMock.new(2, rng.address)
      const tx = await connect.init('0x')
      assert.equal(tx.logs[0].args.initialControl, 2)
    })
  })
  describe('encode state', () => {
    it('should encode the entire board when it is empty', async () => {
      await connect.init('0x')
      const expected = encodeFixedUintArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
      assert.equal(await connect.encodeState(), expected)
    })
    it('should encode the entire board (1)', async () => {
      await connect.init(('0x'))
      await connect.update(1, encodeAction(0, 0))
      const expected = encodeFixedUintArray([1, 0, 0, 0, 0, 0, 0, 0, 0])
      assert.equal(await connect.encodeState(), expected)
    })
    it('should encode the entire board (2)', async () => {
      await connect.init(('0x'))
      await connect.update(1, encodeAction(0, 0))
      await connect.update(2, encodeAction(1, 1))
      await connect.update(1, encodeAction(0, 1))
      const expected = encodeFixedUintArray([1, 0, 0, 1, 2, 0, 0, 0, 0])
      assert.equal(await connect.encodeState(), expected)
    })
  })
  describe('set state', () => {
    it('should set the state correctly', async () => {
      const encoded = encodeFixedUintArray([1, 0, 0, 1, 2, 0, 0, 0, 0])
      await connect.setState(encoded)
      // roundtrip
      assert.equal(await connect.encodeState(), encoded)
    })
  })
})
