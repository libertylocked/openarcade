pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Connect.sol";
import "./RandGen.sol";


contract Controller {
    using SafeMath for uint;

    Game.State state;
    Connect.Info info;
    Connect.Tools tools;
    mapping(address => bool) public deposited;
    uint public depositedCount;
    mapping(address => uint) public players; // value is playerID
    address[] public playersArray;
    LifeCycle public lifecycle;

    uint constant public BET_AMOUNT = 1 ether;

    enum LifeCycle {
        Deposit,
        SetupRNG,
        Play
    }

    event LogPlayerMove(
        address indexed player, uint pid, bytes action
    );
    event LogPayout(address player, uint amount);

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
        (state, info.control) = Connect.init(tools, playersArray.length);
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
        require(Connect.terminal(state) == false);
        // update game state
        Connect.update(state, input);
        // update control
        info.control = Connect.next(state, info);
        // emit log
        emit LogPlayerMove(msg.sender, playerID, _action);
    }

    function payout()
        onlyDuring(LifeCycle.Play)
        public
    {
        // TODO change this to support more than 2 players
        // TODO use withdraw pattern
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
        return info.control;
    }

    function random()
        public view
        returns (address)
    {
        return address(tools.random);
    }
}
