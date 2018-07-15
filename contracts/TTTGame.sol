pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./util/BytesUtil.sol";
import "./Connect.sol";


// TTTGame is the Tic Tac Toe game library
// Note: pid (player ID) is always non zero.
library TTTGame {
    using SafeMath for uint256;
    using BytesUtil for bytes;

    struct State {
        // In TTT, we define the state as simply a mapping which is the board.
        // It's a flattened 2D array
        mapping(bytes32=>Cell) board;
    }

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

    function init(State storage state, Connect.Tools storage tools, uint playerCount)
        internal
        returns (uint)
    {
        // start the game with control setting to random
        // since player ID starts at 0, for a 2 player game it would be 1 or 2
        uint initialControl = (tools.random.next() % playerCount).add(1);
        // since all cells are initialized to zero, no state modification is needed
        return initialControl;
    }

    function next(State storage state, Connect.Info storage info)
        internal view
        returns (uint)
    {
        // In TTT simply alternate
        return (info.control % info.playerCount).add(1);
    }

    function update(State storage state, Connect.Tools storage tools, Connect.Info storage info, Connect.Input memory input)
        internal
    {
        // in TTT only one cell is updated
        Action memory action = input.action;
        state.board[encodeSelector(action.x, action.y)].pid = input.pid;
    }

    function legal(State storage state, Connect.Info storage info, Connect.Input memory input)
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

    function terminal(State storage state, Connect.Info storage info)
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

    function goal(State storage state, Connect.Info storage info, uint pid)
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

    function decodeAction(bytes s)
        internal pure
        returns (Action)
    {
        uint[] memory res = s.sliceUintArray(0, 2);
        return Action({
            x: res[0],
            y: res[1]
        });
    }

    /* External functions */

    /// Encodes an action into bytes
    /// This function is optional!
    /// This function is needed for client to encode the action
    /// @return The encoded action in bytes
    function encodeAction(uint x, uint y)
        external pure
        returns (bytes)
    {
        return abi.encode(x, y);
    }

    /* Private functions */
    // Can be freely defined

    function encodeSelector(uint x, uint y)
        private pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(x, y));
    }

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
