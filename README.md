OpenArcade
---
[![Build Status](https://travis-ci.com/libertylocked/openarcade.svg?token=Zxc7dXTsMTVkgzbD5qVN&branch=master)](https://travis-ci.com/libertylocked/openarcade)
[![Codecov](https://codecov.io/gh/libertylocked/openarcade/branch/master/graph/badge.svg?token=taDYJ6t9PK)](https://codecov.io/gh/libertylocked/openarcade)

# What is OpenArcade?
OpenArcade is a game engine for turn based games (or anything alike) on Ethereum.

## Current Status
> :warning: OA was originally a graduate capstone project. It is released to the public as free software, however due to its nature, OA is unaudited and likely under-tested.

Many features and tools are still yet to be implemented, such as

- Documentations and tutorials
- JavaScript library to interact with the game and the state channel
- Library interface improvements
- Hidden state support
- State channel as a service

## Features
- Easy and simple - You only need to implement an interface of a few functions to get going
- Library driven - Your game logic is only deployed once, saving gas
- Batteries included - It comes with many useful utils suchs as a random number generator
- Out-of-the-box state channel support - Faster and cheaper matches for your game
- Play for money (or not) - OpenArcade supports high stake competitive games
- Not just for games - any rule set can be enforced and the generic state channel can be used for whatever you wish

## Examples
- See `contracts/games` for example games developed on OpenArcade!
- See `test` folder for client example code

# Quick Start
- Copy the starter template at `contracts/games/Starter.sol` to `contracts/games/MyGame.sol`
- Change the import lines marked with TODO in `MyGame.sol`
- Run `npm run prebuild` to generate
- Write your game! Implement the functions marked with TODO
- Write some tests!
    - You can require the mock connector for your game like this in tests
    - See `test/games` for examples
        ```
        const Connect = artifacts.require('MyGameConnectMock')
        ```
    - Or you can require your game controller directly
        ```
        const Controller = artifacts.require('MyGameController')
        ```
- Put the tests in `test` folder
- Run `npm test test/{test-file-for-my-game}`

# Developer Guides
> Coming soon

- ~~Make your first OpenArcade game~~
- ~~Common errors and pitfalls~~

---

Special thanks to Prof. Joseph Bonneau for guidance on the project
