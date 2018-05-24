pragma solidity ^0.4.23;

import "./TTTLibrary.sol";


contract TTTController {
    TTTLibrary.State state;
    address player1;
    address player2;
    bool player1Paid = false;
    bool player2Paid = false;

    constructor(address _player1, address _player2) public {
        state = TTTLibrary.init();
        player1 = _player1;
        player2 = _player2;
    }

    function deposit() payable public {
        require(msg.sender == player1 || msg.sender == player2);
        require(msg.value >= 0.01 ether);
        if (msg.sender == player1) {
            require(!player1Paid);
            player1Paid = true;
        } else {
            require(!player2Paid);
            player2Paid = true;
        }
    }

    function move(uint x, uint y) public {
        require(player1Paid && player2Paid);
        require(msg.sender == player1 || msg.sender == player2);
        uint playerID;
        if (msg.sender == player1) {
            playerID = 1;
        } else {
            playerID = 2;
        }

        TTTLibrary.Input memory input = TTTLibrary.Input({
            playerID: playerID,
            x: x,
            y: y
        });
        TTTLibrary.move(state, input);
    }

    function getPiece(uint x, uint y)
        public view
        returns (uint)
    {
        return state.board[x][y];
    }
}
