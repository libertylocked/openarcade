pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Connect.sol";


contract Controller {
    using SafeMath for uint;

    Connect.State state;
    bool player1Deposited = false;
    bool player2Deposited = false;

    address public player1;
    address public player2;
    uint constant public BET_AMOUNT = 1 ether;

    event LogPlayerMove(
        address indexed player, uint pid, bytes action
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
        state = Connect.init();
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

    function play(bytes action)
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

        Connect.Input memory input = Connect.Input({
            pid: playerID,
            action: Connect.decodeAction(action)
        });
        // check if legal
        require(Connect.legal(state, input));
        // game must not be in terminal state
        require(Connect.terminal(state) == false);
        // update game state
        Connect.Update[] memory updates = Connect.update(state, input);
        for (uint i = 0; i < updates.length; i++) {
            state.board[updates[i].selector] = updates[i].cell;
        }
        // update control
        state.control = Connect.next(state);
        // emit log
        emit LogPlayerMove(msg.sender, playerID, action);
    }

    function payout()
        gameStarted
        public
    {
        // game must be in terminal state
        require(Connect.terminal(state));
        // check score
        uint player1Score = Connect.goal(state, 1);
        uint player2Score = Connect.goal(state, 2);
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
        return Connect.terminal(state);
    }

    function control()
        public view
        returns (uint)
    {
        return state.control;
    }
}
