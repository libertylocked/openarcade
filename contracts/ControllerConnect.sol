pragma solidity 0.4.24;

import { TTTGame as Game } from "./TTTGame.sol";


library ControllerConnect {
    struct State {
        mapping(bytes => Game.Cell) board;
        uint control;
    }
}
