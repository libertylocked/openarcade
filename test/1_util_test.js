/* global artifacts contract assert */
import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'

const Util = artifacts.require('./Util.sol')

contract('Util', () => {
  let lib
  before('get deployed lib instance', async () => {
    lib = await Util.deployed()
  })
  describe('point 1D encoding', () => {
    it('should encode a 1D point correctly', async () => {
      const expected = eutil.bufferToHex(abi.rawEncode(['uint256'], [320]))
      const res = await lib.encodePoint1D(320)
      assert.equal(res, expected)
    })
    it('should decode a 1D point correctly', async () => {
      const encoded = eutil.bufferToHex(abi.rawEncode(['uint256'], [320]))
      const res = await lib.decodePoint1D(encoded)
      assert.equal(res.toNumber(), 320)
    })
  })
  describe('point 2D encoding', () => {
    it('should encode a 2D point correctly', async () => {
      const expected = eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'], [320, 640]))
      const res = await lib.encodePoint2D(320, 640)
      assert.equal(res, expected)
    })
    it('should decode a 2D point correctly', async () => {
      const encoded = eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'], [320, 640]))
      const res = await lib.decodePoint2D(encoded)
      assert.equal(res[0].toNumber(), 320)
      assert.equal(res[1].toNumber(), 640)
    })
  })
  describe('point 3D encoding', () => {
    it('should encode a 3D point correctly', async () => {
      const expected = eutil.bufferToHex(
        abi.rawEncode(['uint256', 'uint256', 'uint256'], [320, 640, 960])
      )
      const res = await lib.encodePoint3D(320, 640, 960)
      assert.equal(res, expected)
    })
    it('should decode a 3D point correctly', async () => {
      const encoded = eutil.bufferToHex(
        abi.rawEncode(['uint256', 'uint256', 'uint256'], [320, 640, 960])
      )
      const res = await lib.decodePoint3D(encoded)
      assert.equal(res[0].toNumber(), 320)
      assert.equal(res[1].toNumber(), 640)
      assert.equal(res[2].toNumber(), 960)
    })
  })
})
