pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "./Connect.sol";
import "./TTTGame.sol";
import "./XRandom.sol";


contract Controller is Ownable, Destructible {
    using SafeMath for uint;

    Game.State state;
    Connect.Info info; // part of state game is not allowed to modify
    Connect.Tools tools;
    mapping(address => bool) public deposited;
    uint public depositedCount;
    mapping(address => uint) public players; // value is playerID
    address[] public playersArray;
    mapping(address => uint) public points;
    uint totalPoints;
    LifeCycle public lifecycle;

    uint constant public BET_AMOUNT = 1 ether;

    enum LifeCycle {
        Depositing,
        Starting,
        Playing,
        Withdrawing
    }

    event LogPlayerMove(
        address indexed player, uint pid, bytes action
    );
    event LogWithdraw(address player, uint amount);

    modifier onlyDuring(LifeCycle _status) {
        require(lifecycle == _status);
        _;
    }

    modifier onlyPlayer() {
        require(players[msg.sender] != 0);
        _;
    }

    modifier rngReady() {
        require(tools.random.state() == XRandom.State.Ready);
        _;
    }

    constructor(address[] _players) public {
        for (uint i = 0; i < _players.length; i++) {
            players[_players[i]] = 1 + i;
        }
        playersArray = _players;
        info = Connect.Info({
            playerCount: _players.length,
            control: 0
        });
        // create RNG contract
        tools = Connect.Tools({
            random: new XRandom(_players, address(this))
        });
        // start in depositing stage
        lifecycle = LifeCycle.Depositing;
    }

    function deposit()
        onlyPlayer
        onlyDuring(LifeCycle.Depositing)
        payable
        external
    {
        // must send exact bet
        require(msg.value == BET_AMOUNT);
        require(!deposited[msg.sender]);
        deposited[msg.sender] = true;
        depositedCount++;
        if (depositedCount == playersArray.length) {
            lifecycle = LifeCycle.Starting;
        }
    }

    function commit(bytes32 _hash)
        onlyPlayer
        external
        returns (bool)
    {
        require(tools.random.commit(msg.sender, _hash));
        return true;
    }

    function reveal(uint _num)
        onlyPlayer
        external
        returns (bool)
    {
        require(tools.random.reveal(msg.sender, _num));
        return true;
    }

    function start()
        onlyDuring(LifeCycle.Starting)
        rngReady()
        external
        returns (bool)
    {
        // init state from game library
        // set state and game info
        info.control = Connect.init(state, tools, playersArray.length);
        lifecycle = LifeCycle.Playing;
    }

    function play(bytes _action)
        onlyPlayer
        onlyDuring(LifeCycle.Playing)
        rngReady()
        external
    {
        uint playerID = players[msg.sender];
        Connect.Input memory input = Connect.Input({
            pid: playerID,
            action: Connect.decodeAction(_action)
        });
        // check if legal
        require(Connect.legal(state, info, input));
        // game must not be in terminal state
        require(Connect.terminal(state, info) == false);
        // update game state
        Connect.update(state, tools, info, input);
        // update control
        info.control = Connect.next(state, info);
        // emit log
        emit LogPlayerMove(msg.sender, playerID, _action);
    }

    function end()
        onlyDuring(LifeCycle.Playing)
        external
    {
        // game ends in terminal state
        require(Connect.terminal(state, info));
        // calculate payout for each player
        uint playerPoints;
        for (uint i = 0; i < playersArray.length; i++) {
            playerPoints = Connect.goal(state, info, players[playersArray[i]]);
            points[playersArray[i]] = playerPoints;
            totalPoints = totalPoints.add(playerPoints);
        }
        // advance state
        lifecycle = LifeCycle.Withdrawing;
    }

    function withdraw()
        onlyPlayer
        onlyDuring(LifeCycle.Withdrawing)
        public
    {
        require(points[msg.sender] > 0);
        uint sendAmount;
        if (totalPoints == 0) {
            sendAmount = BET_AMOUNT.div(playersArray.length);
        } else {
            sendAmount = BET_AMOUNT.mul(playersArray.length)
                .div(totalPoints).mul(points[msg.sender]);
        }
        // clear player points before transfer
        points[msg.sender] = 0;
        msg.sender.transfer(sendAmount);
        emit LogWithdraw(msg.sender, sendAmount);
    }

    function terminal()
        public view
        returns (bool)
    {
        return Connect.terminal(state, info);
    }

    function control()
        public view
        returns (uint)
    {
        return info.control;
    }

    function random()
        public view
        returns (address)
    {
        return address(tools.random);
    }
}
