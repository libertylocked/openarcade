pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Connect.sol";
import "./RandGen.sol";


contract Controller {
    using SafeMath for uint;

    Connect.State state;
    RandGen public rand;
    mapping(address => bool) public deposited;
    uint public depositedCount;
    mapping(address => uint) public players;
    address[] public playersArray;
    LifeCycle public status;

    uint constant public BET_AMOUNT = 1 ether;

    enum LifeCycle {
        Depositing,
        Playing
    }

    event LogPlayerMove(
        address indexed player, uint pid, bytes action
    );
    event LogPayout(address player, uint amount);

    modifier onlyDuring(LifeCycle _status) {
        require(status == _status);
        _;
    }

    modifier playerOnly() {
        require(players[msg.sender] != 0);
        _;
    }

    constructor(address[] _players) public {
        // TODO: set initial control randomly maybe
        state = Connect.init(_players.length);
        state.control = 1;
        for (uint i = 0; i < _players.length; i++) {
            players[_players[i]] = i + 1;
        }
        playersArray = _players;
        // create RNG contract
        rand = new RandGen(_players);
        // start in depositing stage
        status = LifeCycle.Depositing;
    }

    function deposit()
        playerOnly
        onlyDuring(LifeCycle.Depositing)
        payable
        external
    {
        require(msg.value == BET_AMOUNT);
        require(!deposited[msg.sender]);
        deposited[msg.sender] = true;
        depositedCount++;
        if (depositedCount == playersArray.length) {
            status = LifeCycle.Playing;
        }
    }

    function play(bytes action)
        playerOnly
        onlyDuring(LifeCycle.Playing)
        public
    {
        uint playerID = players[msg.sender];
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
        onlyDuring(LifeCycle.Playing)
        public
    {
        // TODO change this to support more than 2 players
        // game must be in terminal state
        require(Connect.terminal(state));
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
            playersArray[0].transfer(player1Pay);
            emit LogPayout(playersArray[0], player1Pay);
        }
        if (player2Pay > 0) {
            playersArray[1].transfer(player2Pay);
            emit LogPayout(playersArray[1], player2Pay);
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
