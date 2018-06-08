pragma solidity 0.4.24;


library TTTLib {
    // player ID starts at 1

    struct State {
        mapping(uint => mapping(uint => uint)) board;
    }

    struct Input {
        uint playerID;
        uint x;
        uint y;
    }

    function init()
        internal pure
        returns (State)
    {
        return State();
    }

    function next(State storage state, uint control)
        internal view
        returns (uint)
    {
        if (control == 1) {
            return 2;
        } else if (control == 2) {
            return 1;
        } else {
            return 0;
        }
    }

    function legal(State storage state, uint control, Input memory input)
        internal view
        returns (bool)
    {
        // player must take turns
        if (control != input.playerID) {
            return false;
        }
        // xy not out of range
        if (input.x < 0 && input.x > 2 && input.y < 0 && input.y > 2) {
            return false;
        }
        // place on empty spot
        if (state.board[input.x][input.y] != 0) {
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

    function goal(State storage state, uint playerID)
        internal view
        returns (uint)
    {
        uint winnerID = checkWinner(state);
        if (winnerID == playerID) {
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
        if (state.board[0][0] != 0 && state.board[0][0] == state.board[0][1] && state.board[0][0] == state.board[0][2]) {
            return state.board[0][0];
        }
        if (state.board[1][0] != 0 && state.board[1][0] == state.board[1][1] && state.board[1][0] == state.board[1][2]) {
            return state.board[1][0];
        }
        if (state.board[2][0] != 0 && state.board[2][0] == state.board[2][1] && state.board[2][0] == state.board[2][2]) {
            return state.board[2][0];
        }
        if (state.board[0][0] != 0 && state.board[0][0] == state.board[1][0] && state.board[0][0] == state.board[2][0]) {
            return state.board[0][0];
        }
        if (state.board[0][1] != 0 && state.board[0][1] == state.board[1][1] && state.board[0][1] == state.board[2][1]) {
            return state.board[0][1];
        }
        if (state.board[0][2] != 0 && state.board[0][2] == state.board[1][2] && state.board[0][2] == state.board[2][2]) {
            return state.board[0][2];
        }
        if (state.board[0][0] != 0 && state.board[0][0] == state.board[1][1] && state.board[0][0] == state.board[2][2]) {
            return state.board[0][0];
        }
        if (state.board[2][0] != 0 && state.board[2][0] == state.board[1][1] && state.board[2][0] == state.board[0][2]) {
            return state.board[2][0];
        }

        return 0;
    }

    function boardFull(State storage state)
        private view
        returns (bool)
    {
        for (uint x = 0; x < 3; x++) {
            for (uint y = 0; y < 3; y++) {
                if (state.board[x][y] == 0) {
                    return false;
                }
            }
        }
        return true;
    }
}
