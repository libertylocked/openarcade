pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./util/BytesUtil.sol";
import "./statechan/Fastforwardable.sol";
import "./random/SerializableRXRandom.sol";
import "./Connect.sol";
import "./TTTGame.sol";


contract Controller is Fastforwardable {
    using SafeMath for uint;
    using BytesUtil for bytes;

    Game.State state;
    Connect.Info info; // part of state game is not allowed to modify
    Connect.Tools tools;
    SerializableRXRandom public random;
    mapping(address => bool) public deposited;
    uint public depositedCount;
    mapping(address => bool) public withdrawn;
    mapping(address => uint) public players; // value is playerID
    address[] public playersArray;
    mapping(address => uint) public points;
    uint totalPoints;
    LifeCycle public lifecycle;
    // fastforward
    uint public lastFastforwardStateIndex;
    // timers for timeouts
    uint public depositDeadline;
    bool public timerStarted;
    uint public timeoutDeadline;

    // tunables
    uint public betAmount;
    uint public depositDuration;
    uint public minTimerDuration;

    enum LifeCycle {
        Depositing,
        Starting,
        Playing,
        Withdrawing
    }

    event LogDeposit(address indexed player);
    event LogGameStart(uint control);
    event LogPlayerMove(
        uint indexed turn, address indexed player, uint pid, bytes action
    );
    event LogWithdraw(address indexed player, uint amount);
    event LogStateFastforward(uint turn);
    event LogTimerStarted(uint turn, bool rngReady, uint deadline);

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

    constructor(address[] _players, uint _betAmount, uint _depositDuration,
        uint _minTimerDuration)
        public
    {
        // set players
        playersArray = _players;
        // set tunables
        betAmount = _betAmount;
        depositDuration = _depositDuration;
        minTimerDuration = _minTimerDuration;
        for (uint i = 0; i < _players.length; ++i) {
            players[_players[i]] = 1 + i;
        }
        info = Connect.Info({
            playerCount: _players.length,
            turn: 0,
            control: 0
        });
        // create RNG contract
        random = new SerializableRXRandom(_players, address(this));
        tools = Connect.Tools({
            random: IRandom(random)
        });
        // start in depositing stage
        lifecycle = LifeCycle.Depositing;
        depositDeadline = block.number + _minTimerDuration;
    }

    function deposit()
        external
        payable
        onlyPlayer
        onlyDuring(LifeCycle.Depositing)
    {
        // must send exact bet
        require(msg.value == betAmount, "must send exact bet amount");
        require(
            !deposited[msg.sender],
            "player must not have already deposited"
        );
        deposited[msg.sender] = true;
        ++depositedCount;
        emit LogDeposit(msg.sender);
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
            "RNG commit fails"
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
        // stop timeout timer upon RNG reveal
        if (timerStarted) {
            timerStarted = false;
        }
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
        info.turn = 1;
        lifecycle = LifeCycle.Playing;
        emit LogGameStart(info.control);
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
        emit LogPlayerMove(info.turn, msg.sender, pid, action);
        // update turn index
        ++info.turn;
        // stop timeout timer
        if (timerStarted) {
            timerStarted = false;
        }
    }

    function end()
        external
        onlyDuring(LifeCycle.Playing)
    {
        // in order for the game to end, the game must either be in terminal state,
        // or player in control missed his/her move and timed out
        require(
            Connect.terminal(state, info),
            "game must be in terminal state"
        );
        // calculate payout for each player
        uint ppoints;
        for (uint i = 0; i < playersArray.length; ++i) {
            ppoints = Connect.goal(state, info, players[playersArray[i]]);
            points[playersArray[i]] = ppoints;
            totalPoints = totalPoints.add(ppoints);
        }
        // advance state
        lifecycle = LifeCycle.Withdrawing;
    }

    function withdraw()
        external
        onlyPlayer
        onlyDuring(LifeCycle.Withdrawing)
    {
        require(deposited[msg.sender], "player never deposited");
        require(!withdrawn[msg.sender], "player has already withdrawn");
        uint sendAmount;
        if (totalPoints == 0) {
            sendAmount = betAmount;
        } else {
            sendAmount = betAmount.mul(playersArray.length)
                .div(totalPoints).mul(points[msg.sender]);
        }
        withdrawn[msg.sender] = true;
        msg.sender.transfer(sendAmount);
        emit LogWithdraw(msg.sender, sendAmount);
    }

    /**
     * @dev Cancels the game and advances the controller to Depositing state.
     * Can only be called during Depositing or Starting, and the deadline has
     * passed. This is useful to cancel the game and refund players in case
     * one or more players drop out during Depositing (by not commiting funds)
     * or drop out during Starting (by not committing a number to RNG)
     */
    function cancelDeposit()
        external
    {
        require(
            lifecycle == LifeCycle.Depositing || lifecycle == LifeCycle.Starting,
            "cancel deposit can only be called in depositing or starting state"
        );
        require(
            block.number >= depositDeadline,
            "cannot cancel deposit before deadline"
        );
        // because during Depositing all players have zero score, setting
        // state to withdrawing allows them to withdraw what they deposited
        lifecycle = LifeCycle.Withdrawing;
    }

    /**
     * @dev Starts the timeout timer for Playing state
     * This function is called by any player in the match, whenever the
     * control player is not making his/her move, or RNG ring turn player is
     * not comitting his/her input.
     * Once the timer is started, it can only be turned off by either the
     * control player sending a move, or RNG commit from ring turn player, or
     * upon a successful state fastforward.
     * Note: This timer only handles timeout during Playing state! Starting
     * and Depositing timeouts are automatically handled without manual timer
     * starts.
     * @param duration the duration of the timer, in number of blocks. There
     *  is a minimal duration that must be met for fairness.
     */
    function startTimer(uint duration)
        external
        onlyPlayer
        onlyDuring(LifeCycle.Playing)
    {
        require(!timerStarted, "timeout timer has already been started");
        require(
            duration >= minTimerDuration,
            "timeout duration too short"
        );
        require(
            Game.terminal(state, info) == false,
            "cannot start timer in terminal state"
        );
        timerStarted = true;
        timeoutDeadline = block.number + duration;
        emit LogTimerStarted(info.turn, random.ready(), timeoutDeadline);
    }

    /**
     * @dev Terminates the game when a player times out.
     * This is an alternative `end` function. It sets players' score and
     * advances the state to Withdrawing.
     */
    function timeout()
        external
        onlyDuring(LifeCycle.Playing)
    {
        require(timerStarted, "timeout timer not started");
        require(
            block.number >= timeoutDeadline,
            "timeout deadline not met yet"
        );
        // calculate score
        uint ppoints;
        uint i;
        for (i = 0; i < playersArray.length; ++i) {
            ppoints = Connect.goal(state, info, players[playersArray[i]]);
            points[playersArray[i]] = ppoints;
            totalPoints = totalPoints.add(ppoints);
        }
        uint droppedOutPlayerID;
        if (random.ready()) {
            // if RNG is ready, the control player should be punished
            droppedOutPlayerID = info.control;
        } else {
            // if RNG is not ready, the ring turn player should be punished
            droppedOutPlayerID = random.ringTurn();
        }
        totalPoints = totalPoints.sub(
            points[playersArray[droppedOutPlayerID]]);
        points[playersArray[droppedOutPlayerID]] = 0;
        // XXX: if players all have zero score, payout should still not be
        // distributed to the dropped out player. So we make every player have
        // 1 point, except the dropped out player
        if (totalPoints == 0) {
            for (i = 0; i < playersArray.length; ++i) {
                points[playersArray[i]] = 1;
            }
            totalPoints = playersArray.length - 1;
        }
        // advance state
        lifecycle = LifeCycle.Withdrawing;
    }

    function terminal()
        external view
        returns (bool)
    {
        return Connect.terminal(state, info);
    }

    function control()
        external view
        returns (uint)
    {
        return info.control;
    }

    function serialize()
        external view
        returns (bytes)
    {
        // The lowest bit is RNG-ready bit, we use that to differentiate
        uint stateIndex = info.turn.mul(2);
        if (random.ready()) {
            ++stateIndex;
        }
        // Note that the lifecycle is not serialized, because it can be
        // referred from turn index
        return abi.encodePacked(
            stateIndex, info.control, random.serialize(),
            Connect.encodeState(state));
    }

    /* Internal functions */

    function getPlayersStorage()
        internal view
        returns (address[] storage playersStorage)
    {
        playersStorage = playersArray;
    }

    function deserialize(bytes cstate)
        internal
    {
        uint rngStateLen = (7 + playersArray.length) * 32;
        require(
            cstate.length >= 64 + rngStateLen,
            "encoded state is too short"
        );
        uint gameStateLen = cstate.length - 64 - rngStateLen;
        uint stateIndex = cstate.sliceUint(0);
        uint turn = stateIndex.div(2);
        uint rngReadyBit = stateIndex % 2;
        // Only allow FF to a state where turn is greater than the turn in the
        // previously fastforward state.
        // Note that the turn in FF request does not have to be greater than
        // the turn in contract state, only that the turn in the FF request
        // cannot have already been fastforwarded. This is to prevent attacks
        // where player FF to a signed but uncommitted state then "commit" the
        // next state on chain, invalidating rest of the uncommitted state. By
        // doing so we allow offchain state signed by all parties to take
        // precedence over the state of contract, yet preventing FF backwards.
        // Another note: the earliest state the contract can FF to is Starting
        // with RNG ready
        require(
            stateIndex > lastFastforwardStateIndex,
            "only forward state is allowed"
        );
        // sef lifecycle
        if (turn == 0) {
            lifecycle = LifeCycle.Starting;
        } else {
            lifecycle = LifeCycle.Playing;
        }
        // set turn and lastFFturn
        info.turn = turn;
        lastFastforwardStateIndex = stateIndex;
        // set control
        info.control = cstate.sliceUint(32);
        // set RNG state
        random.deserializeByOwner(cstate.slice(64, rngStateLen));
        require(
            random.ready() == (rngReadyBit == 1),
            "RNG ready state mismatch"
        );
        // set game state
        Connect.setState(state, cstate.slice(64 + rngStateLen, gameStateLen));
        // stop playing timer
        timerStarted = false;
        emit LogStateFastforward(turn);
    }
}
