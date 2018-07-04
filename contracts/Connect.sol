pragma solidity 0.4.24;

import "./RandGen.sol";
// change this line for other games
import { TTTGame as Game } from "./TTTGame.sol";


// Connect library connects Controller to Game
// GDL inspired interface
library Connect {
    // Info is a piece of Game.State that is read-only to the game library
    struct Info {
        uint playerCount;
        uint control;
    }

    struct Input {
        uint pid;
        Game.Action action;
    }

    struct Tools {
        RandGen random;
    }

    function init(Tools tools, uint playerCount)
        internal
        returns (Game.State, uint)
    {
        return Game.init(tools, playerCount);
    }

    function next(Game.State storage state, Info storage info)
        internal view
        returns (uint)
    {
        return Game.next(state, info);
    }

    function update(Game.State storage state, Input memory input)
        internal
    {
        return Game.update(state, input);
    }

    function legal(Game.State storage state, Info storage info, Input memory input)
        internal view
        returns (bool)
    {
        return Game.legal(state, info, input);
    }

    function terminal(Game.State storage state)
        internal view
        returns (bool)
    {
        return Game.terminal(state);
    }

    function goal(Game.State storage state, uint pid)
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
