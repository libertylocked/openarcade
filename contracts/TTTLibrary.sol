pragma solidity ^0.4.23;


library TTTLibrary {
    // player ID starts at 1

    struct State {
        uint nextTurn;
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
        return State({
            nextTurn: 1
        });
    }

    function move(State storage state, Input memory input)
        internal
        returns (bool)
    {
        require(validateInput(state, input));
        state.board[input.x][input.y] = input.playerID;
        if (input.playerID == 1) {
            state.nextTurn = 2;
        } else {
            state.nextTurn = 1;
        }
        return true;
    }

    function checkWinner(State storage state)
        public view
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

    /* Private functions */

    function validateInput(State storage state, Input memory input)
        private view
        returns (bool)
    {
        // return true or revert
        // player ID is 1 or 2
        require(input.playerID == 1 || input.playerID == 2);
        // player must take turns
        require(state.nextTurn == input.playerID);
        // xy not out of range
        require(input.x >= 0 && input.x <= 2 && input.y >= 0 && input.y <= 2);
        // place on empty spot
        require(state.board[input.x][input.y] == 0);
        return true;
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
