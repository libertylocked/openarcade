pragma solidity 0.4.24;

import "../RandGen.sol";
// change this line for other games
import { MMMGame as Game } from "./MMMGame.sol";


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

    function init(Game.State storage state, Tools storage tools, uint playerCount)
        internal
        returns (uint)
    {
        return Game.init(state, tools, playerCount);
    }

    function next(Game.State storage state, Info storage info)
        internal view
        returns (uint)
    {
        return Game.next(state, info);
    }

    function update(Game.State storage state, Tools storage tools, Input memory input)
        internal
    {
        return Game.update(state, tools, input);
    }

    function legal(Game.State storage state, Info storage info, Input memory input)
        internal view
        returns (bool)
    {
        return Game.legal(state, info, input);
    }

    function terminal(Game.State storage state, Info storage info)
        internal view
        returns (bool)
    {
        return Game.terminal(state, info);
    }

    function goal(Game.State storage state, Info storage info, uint pid)
        internal view
        returns (uint)
    {
        return Game.goal(state, info, pid);
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
