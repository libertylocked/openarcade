pragma solidity 0.4.24;

import "./PlatformLib.sol";


library TTTLib {
    // Tic Tac Toe game library.
    // No function in the library should mutate the state.
    // Some structs can be freely defined, others must follow certain
    //  standards.
    // Internal functions and public functions are strictly defined, their
    //  function signatures should be consistent in all games.
    // Note: pid (player ID) is always non zero.

    /* Structs */

    struct State {
        mapping(bytes => Cell) board;
        uint control;
    }

    struct Update {
        bytes selector; // which cell to update
        Cell cell; // what to update it to
    }

    struct Input {
        uint pid;
        Action action;
    }

    // A player Action
    // Can be freely defined in game library
    struct Action {
        // In TTT, action is simply the location player wants to place a piece
        // at. In other games, this may also include the mark on a cell, or
        // even stuff like directions. Anything you want.
        uint x;
        uint y;
    }

    // Cell in a game board
    // Can be freely defined in game library
    struct Cell {
        // In TTT, only the player who owns the cell is needed in a piece
        // Use 0 for no owner
        uint pid;
    }

    /* Internal functions */
    // All internal functions must be defined with the exact function
    // signatures.

    /// Inits game state
    /// @return the initial game state
    function init()
        internal pure
        returns (State)
    {
        return State({
            control: 0
        });
    }

    /// Gets the next player in control
    /// @return the ID of the next player in control
    function next(State storage state)
        internal view
        returns (uint)
    {
        // In TTT simply alternate
        if (state.control == 1) {
            return 2;
        } else if (state.control == 2) {
            return 1;
        } else {
            return 0;
        }
    }

    /// Gets the game state updates
    /// @return An array of state updates
    function update(State storage state, Input memory input)
        internal view
        returns (Update[])
    {
        // in TTT only one cell is updated
        Action memory action = input.action;
        Update[] memory arr = new Update[](1);
        arr[0] = Update({
            selector: encodeSelector(action.x, action.y),
            cell: Cell({
                pid: input.pid
            })
        });
        return arr;
    }

    /// Checks if a move is legal
    /// @return True if move is legal
    function legal(State storage state, Input memory input)
        internal view
        returns (bool)
    {
        uint x = input.action.x;
        uint y = input.action.y;
        // player must take turns
        if (state.control != input.pid) {
            return false;
        }
        // xy must not be out of range
        if (x < 0 && x > 2 && y < 0 && y > 2) {
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
        (x, y) = PlatformLib.decodePoint2D(s);
        return Action({
            x: x,
            y: y
        });
    }

    /* Public functions */
    // All public functions must be defined with the exact function
    // signatures

    /// Encodes an action into bytes
    /// This function is needed for client to encode the action
    /// @return The encoded action in bytes
    function encodeAction(uint x, uint y)
        public pure
        returns (bytes)
    {
        return PlatformLib.encodePoint2D(x, y);
    }

    /* Private functions */
    // Can be freely defined

    function encodeSelector(uint x, uint y)
        private pure
        returns (bytes)
    {
        return abi.encodePacked(x, y);
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
                    bytes memory colSelect = encodeSelector(i, j);
                    if (state.board[colSelect].pid != colWinner) {
                        colWinner = 0;
                    }
                }
                if (rowWinner != 0) {
                    bytes memory rowSelect = encodeSelector(j, i);
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
                bytes memory ltrSelect = encodeSelector(i, i);
                if (state.board[ltrSelect].pid != ltrWinner) {
                    ltrWinner = 0;
                }
            }
            if (rtlWinner != 0) {
                bytes memory rtlSelect = encodeSelector(2-i, i);
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
