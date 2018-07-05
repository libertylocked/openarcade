pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "./Connect.sol";
import "./RandGen.sol";


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
        Deposit,
        SetupRNG,
        Play,
        Withdraw
    }

    event LogPlayerMove(
        address indexed player, uint pid, bytes action
    );
    event LogWithdraw(address player, uint amount);

    modifier onlyDuring(LifeCycle _status) {
        require(lifecycle == _status);
        _;
    }

    modifier playerOnly() {
        require(players[msg.sender] != 0);
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
            random: new RandGen(_players)
        });
        // start in depositing stage
        lifecycle = LifeCycle.Deposit;
    }

    function deposit()
        playerOnly
        onlyDuring(LifeCycle.Deposit)
        payable
        external
    {
        // must send exact bet
        require(msg.value == BET_AMOUNT);
        require(!deposited[msg.sender]);
        deposited[msg.sender] = true;
        depositedCount++;
        // there is the assumption that Controller and RandGen will go to reveal stage at the same time
        if (depositedCount == playersArray.length) {
            lifecycle = LifeCycle.SetupRNG;
        }
    }

    function commit(bytes32 _hash)
        playerOnly
        onlyDuring(LifeCycle.SetupRNG)
        external
        returns (bool)
    {
        require(tools.random.commit(msg.sender, _hash));
        return true;
    }

    function reveal(uint _num)
        playerOnly
        onlyDuring(LifeCycle.SetupRNG)
        external
        returns (bool)
    {
        require(tools.random.reveal(msg.sender, _num));
        return true;
    }

    function start()
        onlyDuring(LifeCycle.SetupRNG)
        external
        returns (bool)
    {
        // RNG must be ready (committed and revealed)
        require(tools.random.state() == RandGen.State.Ready);
        // init state from game library
        // set state and game info
        info.control = Connect.init(state, tools, playersArray.length);
        lifecycle = LifeCycle.Play;
    }

    function play(bytes _action)
        playerOnly
        onlyDuring(LifeCycle.Play)
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
        Connect.update(state, tools, input);
        // update control
        info.control = Connect.next(state, info);
        // emit log
        emit LogPlayerMove(msg.sender, playerID, _action);
    }

    function end()
        onlyDuring(LifeCycle.Play)
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
        lifecycle = LifeCycle.Withdraw;
    }

    function withdraw()
        playerOnly
        onlyDuring(LifeCycle.Withdraw)
        public
    {
        require(points[msg.sender] > 0);
        uint sendAmount = BET_AMOUNT.mul(playersArray.length)
            .div(totalPoints).mul(points[msg.sender]);
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
