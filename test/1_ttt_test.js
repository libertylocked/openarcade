const TTTLib = artifacts.require("./TTTLib.sol")
const TTTController = artifacts.require("./TTTController.sol")

import expectThrow from "openzeppelin-solidity/test/helpers/expectThrow"

contract("TTTController", (accounts) => {
  let controller
  const player1 = accounts[0]
  const player2 = accounts[1]
  beforeEach("deploy a new TTTController", async () => {
    controller = await TTTController.new(player1, player2)
  })

  describe("constructor", () => {
    it("should set player addresses and control correctly", async () => {
      const instance = await TTTController.new(player1, player2)
      assert.equal(await instance.player1(), player1)
      assert.equal(await instance.player2(), player2)
      assert.equal(await instance.control(), 1)
    })
  })
  describe("deposit", () => {

  })
  describe("play", () => {
    beforeEach("setup game", async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.deposit({
        from: player1,
        value: bet,
      })
      await controller.deposit({
        from: player2,
        value: bet,
      })
    })
    it("should only allow player who has control to play", async () => {
      const tx = await controller.play(0, 0, 0, { from: player1 })
      assert.equal(tx.logs[0].event, "LogPlayerMove")
      assert.equal(tx.logs[0].args.x.toNumber(), 0)
      assert.equal(tx.logs[0].args.y.toNumber(), 0)
      assert.equal(tx.logs[0].args.player, player1)
      const cell = await controller.cell(0, 0)
      assert.equal(cell[0], 1) // its owned by player1
    })
    it("should not allow player who doesn't have control to play", async () => {
      await expectThrow(controller.play(0, 0, 0, { from: player2 }))
    })
    it("control should alternate", async () => {
      await controller.play(0, 0, 0, { from: player1 })
      assert.equal(await controller.control(), 2)
      await expectThrow(controller.play(0, 1, 0, { from: player1 }))
    })
  })
  describe("payout", () => {
    beforeEach("setup game", async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.deposit({
        from: player1,
        value: bet,
      })
      await controller.deposit({
        from: player2,
        value: bet,
      })
    })
    it("should pay the winner when player 1 wins", async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.play(0, 0, 0, { from: player1 })
      await controller.play(0, 1, 0, { from: player2 })
      await controller.play(1, 1, 0, { from: player1 })
      await controller.play(0, 2, 0, { from: player2 })
      await controller.play(2, 2, 0, { from: player1 })
      const tx = await controller.payout({ from: player1 })
      assert.equal(tx.logs[0].event, "LogPayout")
      assert.equal(tx.logs[0].args.player, player1)
      assert.equal(tx.logs[0].args.amount.toString(), bet.mul(2).toString())
    })
    it("should split the payout if match is a draw", async () => {
      const bet = await controller.BET_AMOUNT()
      await controller.play(1, 1, 0, { from: player1 })
      await controller.play(1, 0, 0, { from: player2 })
      await controller.play(0, 0, 0, { from: player1 })
      await controller.play(2, 2, 0, { from: player2 })
      await controller.play(2, 0, 0, { from: player1 })
      await controller.play(0, 2, 0, { from: player2 })
      await controller.play(1, 2, 0, { from: player1 })
      await controller.play(0, 1, 0, { from: player2 })
      await controller.play(2, 1, 0, { from: player1 })
      const tx = await controller.payout({ from: player1 })
      assert.equal(tx.logs[0].event, "LogPayout")
      assert.equal(tx.logs[0].args.player, player1)
      assert.equal(tx.logs[0].args.amount.toString(), bet.toString())
      assert.equal(tx.logs[1].event, "LogPayout")
      assert.equal(tx.logs[1].args.player, player2)
      assert.equal(tx.logs[1].args.amount.toString(), bet.toString())
    })
    it("should not allow payout before terminal state", async () => {
      await controller.play(1, 1, 0, { from: player1 })
      await controller.play(1, 0, 0, { from: player2 })
      await controller.play(0, 0, 0, { from: player1 })
      expectThrow(controller.payout({ from: player1 }))
    })
  })
})
