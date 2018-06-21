pragma solidity 0.4.24;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { TTTLib as GameLib } from "./TTTLib.sol";


contract TTTController {
    using SafeMath for uint;

    GameLib.State state;
    bool player1Deposited = false;
    bool player2Deposited = false;

    address public player1;
    address public player2;
    uint constant public BET_AMOUNT = 1 ether;

    event LogPlayerMove(
        address indexed player, uint pid, bytes selector, uint move
    );
    event LogPayout(address player, uint amount);

    modifier gameStarted() {
        require(player1Deposited && player2Deposited);
        _;
    }

    modifier playerOnly() {
        require(msg.sender == player1 || msg.sender == player2);
        _;
    }

    constructor(address _player1, address _player2) public {
        state = GameLib.init();
        // TODO: set control randomly maybe
        state.control = 1;
        player1 = _player1;
        player2 = _player2;
    }

    function deposit()
        playerOnly
        payable
        public
    {
        require(msg.value == BET_AMOUNT);
        if (msg.sender == player1) {
            require(!player1Deposited);
            player1Deposited = true;
        } else {
            require(!player2Deposited);
            player2Deposited = true;
        }
    }

    function play(bytes selector, uint move)
        playerOnly
        gameStarted
        public
    {
        uint playerID;
        if (msg.sender == player1) {
            playerID = 1;
        } else {
            playerID = 2;
        }

        GameLib.Input memory input = GameLib.Input({
            pid: playerID,
            selector: selector,
            move: move
        });
        // check if legal
        require(GameLib.legal(state, input));
        // game must not be in terminal state
        require(GameLib.terminal(state) == false);
        // update game state
        GameLib.Update[] memory updates = GameLib.update(state, input);
        for (uint i = 0; i < updates.length; i++) {
            state.board[updates[i].selector] = updates[i].piece;
        }
        // update control
        state.control = GameLib.next(state);
        // emit log
        emit LogPlayerMove(msg.sender, playerID, selector, move);
    }

    function payout()
        gameStarted
        public
    {
        // game must be in terminal state
        require(GameLib.terminal(state));
        // check score
        uint player1Score = GameLib.goal(state, 1);
        uint player2Score = GameLib.goal(state, 2);
        uint player1Pay = 0;
        uint player2Pay = 0;
        if (player1Score == player2Score) {
            // split 50/50
            player1Pay = address(this).balance / 2;
            player2Pay = address(this).balance.sub(player1Pay);
        } else if (player1Score > player2Score) {
            // pay player 1
            player1Pay = address(this).balance;
        } else {
            // pay player 2
            player2Pay = address(this).balance;
        }

        // transfer payout
        if (player1Pay > 0) {
            player1.transfer(player1Pay);
            emit LogPayout(player1, player1Pay);
        }
        if (player2Pay > 0) {
            player2.transfer(player2Pay);
            emit LogPayout(player2, player2Pay);
        }
        assert(address(this).balance == 0);
        selfdestruct(0);
    }

    function terminal()
        public view
        returns (bool)
    {
        return GameLib.terminal(state);
    }

    function piece(bytes selector)
        public view
        returns (GameLib.Piece)
    {
        return state.board[selector];
    }

    function control()
        public view
        returns (uint)
    {
        return state.control;
    }
}
