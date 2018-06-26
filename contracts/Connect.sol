pragma solidity 0.4.24;

// change this line for other games
import { TTTGame as Game } from "./TTTGame.sol";


// Connect library connects Controller to Game
// GDL inspired interface
library Connect {
    struct State {
        mapping(bytes => Game.Cell) board;
        uint control;
    }

    struct Update {
        bytes selector; // which cell to update
        Game.Cell cell; // what to update it to
    }

    struct Input {
        uint pid;
        Game.Action action;
    }

    function init()
        internal pure
        returns (State)
    {
        return Game.init();
    }

    function next(State storage state)
        internal view
        returns (uint)
    {
        return Game.next(state);
    }

    function update(State storage state, Input memory input)
        internal view
        returns (Update[])
    {
        return Game.update(state, input);
    }

    function legal(State storage state, Input memory input)
        internal view
        returns (bool)
    {
        return Game.legal(state, input);
    }

    function terminal(State storage state)
        internal view
        returns (bool)
    {
        return Game.terminal(state);
    }

    function goal(State storage state, uint pid)
        internal view
        returns (uint)
    {
        return Game.goal(state, pid);
    }

    function decodeAction(bytes s)
        internal pure
        returns (Game.Action)
    {
        return Game.decodeAction(s);
    }

    function encodeAction(uint x, uint y)
        public pure
        returns (bytes)
    {
        return Game.encodeAction(x, y);
    }
}
