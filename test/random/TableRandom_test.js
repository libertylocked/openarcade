const TableRandom = artifacts.require('TableRandom')

contract('TableRandom', () => {
  let instance
  beforeEach('deploy a new TableRandom instance', async () => {
    instance = await TableRandom.new([1, 2, 3, 4])
  })
  describe('constructor', () => {
    it('should set the random table to the input', async () => {
      const instance = await TableRandom.new([11, 22, 33, 44])
      assert.equal(await instance.rndTable(0), 11)
      assert.equal(await instance.rndTable(1), 22)
      assert.equal(await instance.rndTable(2), 33)
      assert.equal(await instance.rndTable(3), 44)
    })
  })
  describe('ready', () => {
    it('should always return true', async () => {
      assert.isTrue(await instance.ready.call())
      // try calling next
      await instance.next()
      assert.isTrue(await instance.ready.call())
      // try calling request
      await instance.request()
      assert.isTrue(await instance.ready.call())
    })
  })
  describe('request', () => {
    it('should reset index to zero', async () => {
      await instance.next()
      await instance.request()
      assert.equal(await instance.index.call(), 0)
    })
  })
  describe('current', () => {
    it('should return the first number in table if next is not called', async () => {
      assert.equal(await instance.current.call(), 1)
    })
    it('should return the current number in table as cursor moves', async () => {
      await instance.next()
      assert.equal(await instance.current.call(), 2)
      await instance.next()
      assert.equal(await instance.current.call(), 3)
    })
    it('should wrap around', async () => {
      await instance.next()
      await instance.next()
      await instance.next()
      await instance.next()
      assert.equal(await instance.current.call(), 1)
    })
  })
})
