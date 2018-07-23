pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "./random/RXRandom.sol";
import "./Connect.sol";
import "./TTTGame.sol";


contract Controller is Ownable, Destructible {
    using SafeMath for uint;

    Game.State state;
    Connect.Info info; // part of state game is not allowed to modify
    Connect.Tools tools;
    RXRandom public random;
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
        require(
            lifecycle == _status,
            "must match controller lifecycle status"
        );
        _;
    }

    modifier onlyPlayer() {
        require(players[msg.sender] != 0, "sender must be player");
        _;
    }

    modifier rngReady() {
        require(
            random.ready(),
            "RNG must be ready"
        );
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
        random = new RXRandom(_players, address(this));
        tools = Connect.Tools({
            random: IRandom(random)
        });
        // start in depositing stage
        lifecycle = LifeCycle.Depositing;
    }

    function deposit()
        external
        payable
        onlyPlayer
        onlyDuring(LifeCycle.Depositing)
    {
        // must send exact bet
        require(msg.value == BET_AMOUNT, "must send exact bet amount");
        require(
            !deposited[msg.sender],
            "player must not have already deposited"
        );
        deposited[msg.sender] = true;
        depositedCount++;
        if (depositedCount == playersArray.length) {
            lifecycle = LifeCycle.Starting;
        }
    }

    function commit(bytes32 inputHash)
        external
        onlyPlayer
        returns (bool)
    {
        require(
            random.commit(msg.sender, inputHash),
            "RNG commit fail"
        );
        return true;
    }

    function revealAndCommit(uint input, bytes32 inputHash)
        external
        onlyPlayer
        returns (bool)
    {
        require(
            random.revealAndCommit(msg.sender, input, inputHash),
            "RNG reveal fails"
        );
        return true;
    }

    function start(bytes initParams)
        external
        onlyDuring(LifeCycle.Starting)
        rngReady()
        returns (bool)
    {
        // init state from game library
        // set state and game info
        info.control = Connect.init(
            state, tools, playersArray.length,
            initParams
        );
        lifecycle = LifeCycle.Playing;
    }

    function play(bytes action)
        external
        onlyPlayer
        onlyDuring(LifeCycle.Playing)
        rngReady()
    {
        uint pid = players[msg.sender];
        Connect.Input memory input = Connect.Input({
            pid: pid,
            action: Connect.decodeAction(action)
        });
        // check if legal
        require(
            Connect.legal(state, info, input),
            "input is not legal"
        );
        // game must not be in terminal state
        require(
            Connect.terminal(state, info) == false,
            "game is already in terminal state"
        );
        // update game state
        Connect.update(state, tools, info, input);
        // update control
        info.control = Connect.next(state, info);
        // emit log
        emit LogPlayerMove(msg.sender, pid, action);
    }

    function end()
        external
        onlyDuring(LifeCycle.Playing)
    {
        // game ends in terminal state
        require(
            Connect.terminal(state, info),
            "game must be in terminal state"
        );
        // calculate payout for each player
        uint ppoints;
        for (uint i = 0; i < playersArray.length; i++) {
            ppoints = Connect.goal(state, info, players[playersArray[i]]);
            points[playersArray[i]] = ppoints;
            totalPoints = totalPoints.add(ppoints);
        }
        // advance state
        lifecycle = LifeCycle.Withdrawing;
    }

    function withdraw()
        public
        onlyPlayer
        onlyDuring(LifeCycle.Withdrawing)
    {
        require(
            points[msg.sender] > 0,
            "player can only withdraw if player's score is not zero"
        );
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
}
