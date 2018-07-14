pragma solidity 0.4.24;

import "./XRandom.sol";
// change this line for other games
import { TTTGame as Game } from "./TTTGame.sol";


// Connect library defines the interface of a game logic library
// Note: pid (player ID) is always non zero!
library Connect {
    /* Struct definitions */
    // Structs that must be defined in game library:
    // struct State - the state layout of the game
    // struct Action - the action of a player

    // Info is a piece of state that is read-only to the game library
    // This is the info about current match
    struct Info {
        uint playerCount;
        uint control;
    }

    // Input from player
    struct Input {
        // pid is the player ID. It starts at 1!
        uint pid;
        // action is the action the player is performing
        Game.Action action;
    }

    // Game platform tools injected into the game
    struct Tools {
        XRandom random;
    }

    /* Internal functions */
    // All internal functions below must be implemented in the game library with the
    // exact function signatures.

    /**
     * @dev Inits game state. This function should modify the state being passed in
     * @param state The game state. Everything is at its default value in the state
     * @param tools Platform tools
     * @param playerCount Number of players
     * @return The ID of the initial player who will be in control
     */
    function init(Game.State storage state, Tools storage tools, uint playerCount)
        internal
        returns (uint)
    {
        return Game.init(state, tools, playerCount);
    }

    /**
     * @dev Gets the next player in control
     * @param state The game state
     * @param info Info about current match
     * @return The ID of the next player who will be in control
     */
    function next(Game.State storage state, Info storage info)
        internal view
        returns (uint)
    {
        return Game.next(state, info);
    }

    /**
     * @dev Updates the game state
     * @param state The game state
     * @param tools Platform tools
     * @param info Info about current match
     */
    function update(Game.State storage state, Tools storage tools, Info storage info, Input memory input)
        internal
    {
        return Game.update(state, tools, info, input);
    }

    /**
     * @dev Checks if a move is legal
     * @param state The game state
     * @param info Info about current match
     * @param input Player input
     * @return True if move is legal
     */
    function legal(Game.State storage state, Info storage info, Input memory input)
        internal view
        returns (bool)
    {
        return Game.legal(state, info, input);
    }

    /**
     * @dev Checks if game is in terminal state
     * @param state The game state
     * @param info Info about current match
     * @return True if state is terminal
     */
    function terminal(Game.State storage state, Info storage info)
        internal view
        returns (bool)
    {
        return Game.terminal(state, info);
    }

    /**
     * @dev Gets the score of a player
     * @param state The game state
     * @param info Info about current match
     * @param pid The player ID to get the score of
     * @return Any number as player's score
     */
    function goal(Game.State storage state, Info storage info, uint pid)
        internal view
        returns (uint)
    {
        return Game.goal(state, info, pid);
    }

    /**
     * @dev Decodes an action from bytes
     * @param s The encoded action
     * @return An object of type Game.Action
     */
    function decodeAction(bytes s)
        internal pure
        returns (Game.Action)
    {
        return Game.decodeAction(s);
    }

    /* External functions */

    // Optionally, game library can define a function called `encodeAction`, which can
    // be accessed by JavaScript clients to encode an action into bytes.
    // If this function is absent in library contract, game developer must provide a
    // JavaScript function to encode actions.
    //
    // function encodeAction(...)
    //     external pure
    //     returns (bytes)
}
