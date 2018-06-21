pragma solidity 0.4.24;

import "./PlatformLib.sol";


library TTTLib {
    // pid (player ID) is non zero

    struct State {
        mapping(bytes => Cell) board;
        uint control;
    }

    struct Update {
        bytes selector;
        Cell cell;
    }

    struct Input {
        uint pid;
        bytes selector;
        uint action;
    }

    // Cell in a game board
    // Can be freely defined in game library
    struct Cell {
        uint pid; // 0 for no owner
    }

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

    function next(State storage state)
        internal view
        returns (uint)
    {
        if (state.control == 1) {
            return 2;
        } else if (state.control == 2) {
            return 1;
        } else {
            return 0;
        }
    }

    function update(State storage state, Input memory input)
        internal view
        returns (Update[])
    {
        // in TTT only one cell is updated
        Update[] memory arr = new Update[](1);
        arr[0] = Update({
            selector: input.selector,
            cell: Cell({
                pid: input.pid
            })
        });
        return arr;
    }

    function legal(State storage state, Input memory input)
        internal view
        returns (bool)
    {
        uint x = 0;
        uint y = 0;
        (x, y) = decodeSelector(input.selector);
        // player must take turns
        if (state.control != input.pid) {
            return false;
        }
        // xy must not be out of range
        if (x < 0 && x > 2 && y < 0 && y > 2) {
            return false;
        }
        // must place on empty spot
        if (state.board[input.selector].pid != 0) {
            return false;
        }
        return true;
    }

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

    /* Private functions */
    function decodeSelector(bytes s)
        private pure
        returns (uint, uint)
    {
        return PlatformLib.decodePoint2D(s);
    }

    function encodeSelector(uint x, uint y)
        private pure
        returns (bytes)
    {
        return PlatformLib.encodePoint2D(x, y);
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
