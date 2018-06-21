const PlatformLib = artifacts.require("./PlatformLib.sol")
const eutil = require('ethereumjs-util')
const abi = require('ethereumjs-abi')

contract("PlatformLib", () => {
  let lib
  before("get deployed lib instance", async () => {
    lib = await PlatformLib.deployed()
  })
  describe("serialize point 2D", () => {
    it("should serialize a 2D point correctly", async () => {
      const expected = eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'], [320, 640]))
      const res = await lib.serializePoint2D(320, 640)
      assert.equal(res, expected)
    })
    it("should deserialize a 2D point correctly", async () => {
      const encoded = eutil.bufferToHex(abi.rawEncode(['uint256', 'uint256'], [320, 640]))
      const res = await lib.deserializePoint2D(encoded)
      assert.equal(res[0].toNumber(), 320)
      assert.equal(res[1].toNumber(), 640)
    })
  })
  describe("serialize point 3D", () => {
    it("should serialize a 3D point correctly", async () => {
      const expected = eutil.bufferToHex(
        abi.rawEncode(['uint256', 'uint256', 'uint256'], [320, 640, 960])
      )
      const res = await lib.serializePoint3D(320, 640, 960)
      assert.equal(res, expected)
    })
    it("should deserialize a 3D point correctly", async () => {
      const encoded = eutil.bufferToHex(
        abi.rawEncode(['uint256', 'uint256', 'uint256'], [320, 640, 960])
      )
      const res = await lib.deserializePoint3D(encoded)
      assert.equal(res[0].toNumber(), 320)
      assert.equal(res[1].toNumber(), 640)
      assert.equal(res[2].toNumber(), 960)
    })
  })
})
