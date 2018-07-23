pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../access/Relayable.sol";
import "./IRandom.sol";


// Ring XOR keccak-256 random number generator
// In round -2 everyone commits, in any order.
// In round -1 everyone reveals, then commits, in any order.
// At the beginning of round 0, the RNG seed becomes ready.
// The seed can be used to call next as many times as you want, until new
//   randomness is needed. In which case a new seed should be requested, and
//   RNG will go into "pending update" state.
// When there is pending update, the seed is unavailable.
// Once new seed is requested, the next person in ring does commit then reveal.
// This will cause the seed to be updated, and seed becomes ready again.
//
// The state goes like this
// InitialCommit -> InitialReveal -> Ready -> PendingUpdate -> Ready -> ...
contract RXRandom is Ownable, Relayable {
    mapping(address => bool) public players;
    address[] public playersArray;
    mapping(address => bytes32) public commits;
    mapping(address => uint) public reveals;
    State public state;
    uint public roundNeg2CommitCount;
    uint public roundNeg1CommitCount;
    // Ring
    uint public ringTurn;
    // Random numbers
    uint public seed;
    uint public current;
    uint public index;

    enum State {
        RoundNeg2, // ring round -2
        RoundNeg1, // ring round -1
        Ready, // ready at beginning of round 0, unless there's pending update
        PendingUpdate // pending update can only occur in round 0+
    }

    event LogCommitted(address player, bytes32 commit);
    event LogRevealed(address player, uint input);
    event LogStateChanged(State state);
    event LogRandomGenerated(uint seed, uint index, uint number);

    modifier onlyPlayer(address sender) {
        require(
            players[sender],
            "sender must be player or relayed from player"
        );
        _;
    }

    modifier onlyNotCommitted(address sender) {
        require(
            commits[sender] == 0,
            "player must not have already committed"
        );
        _;
    }

    modifier onlyNotRevealed(address sender) {
        require(
            reveals[sender] == 0,
            "player must not have already revealed"
        );
        _;
    }

    modifier onlyDuring(State _state) {
        require(state == _state, "state must match");
        _;
    }

    constructor(address[] _players, address _relayer)
        public
        Relayable(_relayer)
    {
        for (uint i = 0; i < _players.length; i++) {
            players[_players[i]] = true;
        }
        playersArray = _players;
        state = State.RoundNeg2;
    }

    function commit(address sender, bytes32 inputHash)
        external
        onlyRelayer
        onlyDuring(State.RoundNeg2)
        returns (bool)
    {
        // commit can only be called in round -2
        // in round -1 and beyond players call revealAndCommit
        mCommit(sender, inputHash);
        roundNeg2CommitCount++;
        // XXX maybe have explicit round advance
        if (roundNeg2CommitCount == playersArray.length) {
            mChangeState(State.RoundNeg1);
        }
        return true;
    }

    function revealAndCommit(address sender, uint reveal, bytes32 inputHash)
        external
        onlyRelayer
        returns (bool)
    {
        // state can be either in pending update or round -2
        require(
            state == State.RoundNeg1 || state == State.PendingUpdate,
            "can only be called during round -1 or pending update state"
        );
        if (state == State.PendingUpdate) {
            // it must be sender's turn in ring
            require(
                sender == playersArray[ringTurn % playersArray.length],
                "must be players turn in ring"
            );
        }
        // do reveal then do commit
        mReveal(sender, reveal);
        mCommit(sender, inputHash);
        if (state == State.RoundNeg1) {
            // if we are at round -1 we need to check if we need to advance state
            roundNeg1CommitCount++;
            // XXX maybe have explicit round advance
            if (roundNeg1CommitCount == playersArray.length) {
                // RNG is ready at the end of round -1
                // This marks the start of round 0
                mChangeState(State.Ready);
            }
        } else if (state == State.PendingUpdate) {
            // increment ring turn and set state back to ready
            ringTurn++;
            mChangeState(State.Ready);
        }
        return true;
    }

    function request()
        external
        onlyOwner
        onlyDuring(State.Ready)
        returns (bool)
    {
        mChangeState(State.PendingUpdate);
        return true;
    }

    function next()
        external
        onlyOwner
        onlyDuring(State.Ready)
        returns (uint)
    {
        current = uint(keccak256(abi.encodePacked(current)));
        index++;
        emit LogRandomGenerated(seed, index, current);
        return current;
    }

    /* Constant functions */

    function current()
        external view
        onlyDuring(State.Ready)
        returns (uint)
    {
        return current;
    }

    function ready()
        external view
        returns (bool)
    {
        return state == State.Ready;
    }

    function playerCount()
        external view
        returns (uint)
    {
        return playersArray.length;
    }

    /* Private functions */

    function mChangeState(State newState)
        private
    {
        state = newState;
        emit LogStateChanged(newState);
    }

    function mCommit(address sender, bytes32 _hash)
        private
        onlyPlayer(sender)
        onlyNotCommitted(sender)
    {
        // the commit can't be zero or hashed zero
        require(_hash != 0, "commit cannot be zero");
        require(
            _hash != keccak256(abi.encodePacked(uint(0))),
            "commit cannot be hashed zero"
        );
        commits[sender] = _hash;
        reveals[sender] = 0; // once committed, reveal is no longer valid
        emit LogCommitted(sender, _hash);
    }

    function mReveal(address sender, uint _num)
        private
        onlyPlayer(sender)
        onlyNotRevealed(sender)
    {
        // check commit
        require(
            keccak256(abi.encodePacked(_num)) == commits[sender],
            "reveal does not match commit"
        );
        reveals[sender] = _num;
        // once revealed, commit is no longer valid
        commits[sender] = bytes32(0);
        emit LogRevealed(sender, _num);
        // reveal always updates the seed
        mUpdateSeed(_num);
    }

    function mUpdateSeed(uint input)
        private
    {
        seed ^= input;
        current = seed;
        index = 0;
    }

}
