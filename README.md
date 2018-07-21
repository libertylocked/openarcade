OpenArcade
---

# What is OpenArcade?
OpenArcade is a game engine for turn based games on Ethereum.

## Features
- Easy and simple - You only need to implement an interface of a few functions to get going
- Library driven - Your game logic is only deployed once, saving gas
- Batteries included - It comes with many useful utils suchs as a random number generator
- Out-of-the-box state channel support - Faster and cheaper matches for your game
- Play for money (or not) - OpenArcade supports high stake competitive games

## Examples
- See `contracts/games` for example games developed on OpenArcade!
- See `test` folder for client example code

# Quick start
- Copy the starter template at `contracts/games/Starter.sol` to `contracts/games/MyGame.sol`
- Implement the functions marked as TODOs
- Run `npm run compile`
- Write some tests! You can require your game controller like this in tests
```javascript
const Controller = artifacts.require('DiceController')
```
- Put the tests in `test` folder
- Run `npm run test`

# Developer Guides
- [Make your first OpenArcade game](#)
- [Common pitfalls](#)
