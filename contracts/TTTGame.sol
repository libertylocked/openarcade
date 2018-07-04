pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Connect.sol";
import "./Util.sol";


// TTTGame is the Tic Tac Toe game library
// No function in the library should mutate the state.
// Internal functions and public functions are strictly defined, their
//  function signatures should be consistent in all games.
// Structs can be freely modified, as long as their names do not change.
// Note: pid (player ID) is always non zero.
library TTTGame {
    // State is the state of the game
    // This struct must be defined, but the layout is up to the game developer
    struct State {
        // In TTT, we define the state as simply a mapping which is the board.
        // It's a flattened 2D array
        mapping(bytes32=>Cell) board;
    }

    // Action is the action of a player
    // This struct must be defined, but the layout is up to the game developer
    struct Action {
        // In TTT, action is simply the location player wants to place a piece
        // at. In other games, this may also include the mark on a cell, or
        // even stuff like directions. Anything you want.
        uint x;
        uint y;
    }

    struct Cell {
        // In TTT, only the player who owns the cell is needed in a piece
        // Use 0 for no owner
        uint pid;
    }

    /* Internal functions */
    // All internal functions must be defined with the exact function
    //  signatures.

    /// Inits game state
    /// @return the initial game state
    function init(Connect.Tools tools, uint playerCount)
        internal
        returns (State, uint)
    {
        // start the game with control setting to random
        // since player ID starts at 0, for a 2 player game it would be 1 or 2
        uint initialControl = 1 + tools.random.next() % playerCount;
        return (State(), initialControl);
    }

    /// Gets the next player in control
    /// @return the ID of the next player in control
    function next(State storage state, Connect.Info storage info)
        internal view
        returns (uint)
    {
        // In TTT simply alternate
        return 1 + info.control % info.playerCount;
    }

    /// Gets the game state updates
    /// @return An array of state updates
    function update(State storage state, Connect.Input memory input)
        internal
    {
        // in TTT only one cell is updated
        Action memory action = input.action;
        state.board[encodeSelector(action.x, action.y)].pid = input.pid;
    }

    /// Checks if a move is legal
    /// @return True if move is legal
    function legal(State storage state, Connect.Info info, Connect.Input memory input)
        internal view
        returns (bool)
    {
        uint x = input.action.x;
        uint y = input.action.y;
        // player can only play in his/her turn
        if (info.control != input.pid) {
            return false;
        }
        // xy must not be out of range
        if (x < 0 || x > 2 || y < 0 || y > 2) {
            return false;
        }
        // must place on empty spot
        if (state.board[encodeSelector(x, y)].pid != 0) {
            return false;
        }
        return true;
    }

    /// Checks if state is terminal
    /// @return True if in terminal state
    function terminal(State storage state)
        internal view
        returns (bool)
    {
        // either board is full or someone has won the game
        if (boardFull(state)) {
            return true;
        }
        if (checkWinner(state) != 0) {
            return true;
        }
        return false;
    }

    /// Gets the score of a player
    /// @return A number between 0 and 100 (inclusive)
    function goal(State storage state, uint pid)
        internal view
        returns (uint)
    {
        if (boardFull(state)) {
            // if board is full, both players get 50 points
            return 50;
        }
        uint winnerID = checkWinner(state);
        if (winnerID == pid) {
            return 100;
        } else {
            return 0;
        }
    }

    /// Decodes an action from bytes
    /// @return The decoded action
    function decodeAction(bytes s)
        internal pure
        returns (Action)
    {
        uint x = 0;
        uint y = 0;
        (x, y) = Util.decodePoint2D(s);
        return Action({
            x: x,
            y: y
        });
    }

    /* Public functions */
    // All public functions must be defined with the exact function
    //  signatures

    /// Encodes an action into bytes
    /// This function is needed for client to encode the action
    /// @return The encoded action in bytes
    function encodeAction(uint x, uint y)
        public pure
        returns (bytes)
    {
        return Util.encodePoint2D(x, y);
    }

    /* Private functions */
    // Can be freely defined

    function encodeSelector(uint x, uint y)
        private pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(x, y));
    }

    // 0 no winner yet, 1 or 2 if any player has won the game
    function checkWinner(State storage state)
        private view
        returns (uint)
    {
        // XXX
        // maybe excessive gas usage
        for (uint i = 0; i < 3; i++) {
            uint colWinner = state.board[encodeSelector(i, 0)].pid;
            uint rowWinner = state.board[encodeSelector(0, i)].pid;
            for (uint j = 1; j < 3; j++) {
                if (colWinner != 0) {
                    bytes32 colSelect = encodeSelector(i, j);
                    if (state.board[colSelect].pid != colWinner) {
                        colWinner = 0;
                    }
                }
                if (rowWinner != 0) {
                    bytes32 rowSelect = encodeSelector(j, i);
                    if (state.board[rowSelect].pid != rowWinner) {
                        rowWinner = 0;
                    }
                }
            }
            if (colWinner != 0) {
                return colWinner;
            } else if (rowWinner != 0) {
                return rowWinner;
            }
        }
        // check diagonals
        uint ltrWinner = state.board[encodeSelector(0, 0)].pid;
        uint rtlWinner = state.board[encodeSelector(2, 0)].pid;
        for (i = 1; i < 3; i++) {
            if (ltrWinner != 0) {
                bytes32 ltrSelect = encodeSelector(i, i);
                if (state.board[ltrSelect].pid != ltrWinner) {
                    ltrWinner = 0;
                }
            }
            if (rtlWinner != 0) {
                bytes32 rtlSelect = encodeSelector(2-i, i);
                if (state.board[rtlSelect].pid != rtlWinner) {
                    rtlWinner = 0;
                }
            }
        }
        if (ltrWinner != 0) {
            return ltrWinner;
        } else if (rtlWinner != 0) {
            return rtlWinner;
        }
        return 0;
    }

    function boardFull(State storage state)
        private view
        returns (bool)
    {
        for (uint x = 0; x < 3; x++) {
            for (uint y = 0; y < 3; y++) {
                if (state.board[encodeSelector(x, y)].pid == 0) {
                    return false;
                }
            }
        }
        return true;
    }
}
