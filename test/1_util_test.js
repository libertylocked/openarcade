import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
import abi from 'ethereumjs-abi'
import eutil from 'ethereumjs-util'

const BytesUtilMock = artifacts.require('BytesUtilMock')

contract('BytesUtil', () => {
  let lib
  before('deploy bytes util', async () => {
    lib = await BytesUtilMock.new()
  })
  describe('slice uint', () => {
    it('should slice a uint from byte array starting at zero', async () => {
      const bs = eutil.bufferToHex(abi.rawEncode(['uint256'], [320]))
      const res = await lib.sliceUint(bs, 0)
      assert.equal(res.toNumber(), 320)
    })
    it('should slice a uint from byte array starting non zero', async () => {
      const bs = eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'], [42, 1337]))
      const res = await lib.sliceUint(bs, 32)
      assert.equal(res.toNumber(), 1337)
    })
    it('should throw if slicing out of range', async () => {
      const bs = eutil.bufferToHex(abi.rawEncode(['uint256'], [320]))
      await assertRevert(lib.sliceUint(bs, 32))
    })
  })
  describe('slice uints', () => {
    it('should slice an array of uints starting at zero', async () => {
      const bs = eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256', 'uint256'], [320, 640, 1080]))
      const res = await lib.sliceUints(bs, 0, 2)
      assert.equal(res.length, 2)
      assert.equal(res[0].toNumber(), 320)
      assert.equal(res[1].toNumber(), 640)
    })
    it('should slice an array of uints starting at non zero', async () => {
      const bs = eutil.bufferToHex(
        abi.rawEncode(['uint256', 'uint256', 'uint256', 'uint256'], [320, 640, 1080, 2160]))
      const res = await lib.sliceUints(bs, 32, 3)
      assert.equal(res.length, 3)
      assert.equal(res[0].toNumber(), 640)
      assert.equal(res[1].toNumber(), 1080)
      assert.equal(res[2].toNumber(), 2160)
    })
  })
})
