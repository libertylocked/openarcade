pragma solidity 0.4.24;


library TTTLib {
    // pid (player ID) is non zero

    struct State {
        mapping(uint => mapping(uint => Piece)) board;
        uint control;
    }

    struct Piece {
        uint pid; // 0 for no owner
        uint mark; // in TTT this is not used
    }

    struct Update {
        uint x;
        uint y;
        Piece piece;
    }

    struct Input {
        uint pid;
        uint x;
        uint y;
        uint move;
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

    /**
     * Updates board
     */
    function update(State storage state, Input memory input)
        internal view
        returns (Update[])
    {
        // in TTT only one piece is updated
        Update[] memory arr = new Update[](1);
        arr[0] = Update({
            x: input.x,
            y: input.y,
            piece: Piece({
                pid: input.pid,
                mark: input.move
            })
        });
        return arr;
    }

    function legal(State storage state, Input memory input)
        internal view
        returns (bool)
    {
        // player must take turns
        if (state.control != input.pid) {
            return false;
        }
        // xy not out of range
        if (input.x < 0 && input.x > 2 && input.y < 0 && input.y > 2) {
            return false;
        }
        // place on empty spot
        if (state.board[input.x][input.y].pid != 0) {
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

    // 0 no winner yet, 1 or 2 if any player has won the game
    function checkWinner(State storage state)
        private view
        returns (uint)
    {
        // XXX
        /* solium-disable-next-line operator-whitespace */
        if (state.board[0][0].pid != 0 &&
            state.board[0][0].pid == state.board[0][1].pid &&
            state.board[0][0].pid == state.board[0][2].pid) {
            return state.board[0][0].pid;
        }
        /* solium-disable-next-line operator-whitespace */
        if (state.board[1][0].pid != 0 &&
            state.board[1][0].pid == state.board[1][1].pid &&
            state.board[1][0].pid == state.board[1][2].pid) {
            return state.board[1][0].pid;
        }
        /* solium-disable-next-line operator-whitespace */
        if (state.board[2][0].pid != 0 &&
            state.board[2][0].pid == state.board[2][1].pid &&
            state.board[2][0].pid == state.board[2][2].pid) {
            return state.board[2][0].pid;
        }
        /* solium-disable-next-line operator-whitespace */
        if (state.board[0][0].pid != 0 &&
            state.board[0][0].pid == state.board[1][0].pid &&
            state.board[0][0].pid == state.board[2][0].pid) {
            return state.board[0][0].pid;
        }
        /* solium-disable-next-line operator-whitespace */
        if (state.board[0][1].pid != 0 &&
            state.board[0][1].pid == state.board[1][1].pid &&
            state.board[0][1].pid == state.board[2][1].pid) {
            return state.board[0][1].pid;
        }
        /* solium-disable-next-line operator-whitespace */
        if (state.board[0][2].pid != 0 &&
            state.board[0][2].pid == state.board[1][2].pid &&
            state.board[0][2].pid == state.board[2][2].pid) {
            return state.board[0][2].pid;
        }
        /* solium-disable-next-line operator-whitespace */
        if (state.board[0][0].pid != 0 &&
            state.board[0][0].pid == state.board[1][1].pid &&
            state.board[0][0].pid == state.board[2][2].pid) {
            return state.board[0][0].pid;
        }
        /* solium-disable-next-line operator-whitespace */
        if (state.board[2][0].pid != 0 &&
            state.board[2][0].pid == state.board[1][1].pid &&
            state.board[2][0].pid == state.board[0][2].pid) {
            return state.board[2][0].pid;
        }

        return 0;
    }

    function boardFull(State storage state)
        private view
        returns (bool)
    {
        for (uint x = 0; x < 3; x++) {
            for (uint y = 0; y < 3; y++) {
                if (state.board[x][y].pid == 0) {
                    return false;
                }
            }
        }
        return true;
    }
}
