pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


// Random number generator using commit-reveal.
// This contract should be deployed by a controller
contract RandGen is Ownable {
    mapping(address => bool) public players;
    uint public playerCount;
    mapping(address => bytes32) public commits;
    uint public commitCount;
    mapping(address => uint) public reveals;
    uint public revealCount;
    State public state;
    // RNG related stuff
    uint public seed;
    uint public index;

    enum State {
        Commit,
        Reveal,
        Done
    }

    event LogCommitted(address player, bytes32 commit);
    event LogRevealed(address player, uint number);
    event LogStateChanged(State state);
    event LogRandomGenerated(uint index, uint number);

    modifier onlyPlayer() {
        require(players[msg.sender]);
        _;
    }

    modifier onlyNotCommitted() {
        require(commits[msg.sender] == 0);
        _;
    }

    modifier onlyNotRevealed() {
        require(reveals[msg.sender] == 0);
        _;
    }

    modifier onlyDuring(State _state) {
        require(state == _state);
        _;
    }

    constructor(address[] _players) public {
        for (uint i = 0; i < _players.length; i++) {
            players[_players[i]] = true;
        }
        playerCount = _players.length;
        state = State.Commit;
    }

    function commit(bytes32 _commit)
        onlyPlayer
        onlyNotCommitted
        onlyDuring(State.Commit)
        public
        returns (bool)
    {
        // the commit can't be zero or hashed zero
        require(_commit != 0);
        require(_commit != keccak256(abi.encodePacked(uint(0))));
        commits[msg.sender] = _commit;
        commitCount++;
        emit LogCommitted(msg.sender, _commit);
        if (commitCount == playerCount) {
            state = State.Reveal;
            emit LogStateChanged(State.Reveal);
        }
        return true;
    }

    function reveal(uint _num)
        onlyPlayer
        onlyNotRevealed
        onlyDuring(State.Reveal)
        public
        returns (bool)
    {
        // check commit
        require(keccak256(abi.encodePacked(_num)) == commits[msg.sender]);
        reveals[msg.sender] = _num;
        revealCount++;
        emit LogRevealed(msg.sender, _num);
        seed ^= _num;
        if (revealCount == playerCount) {
            state = State.Done;
            emit LogStateChanged(State.Done);
        }
    }

    function current()
        onlyDuring(State.Done)
        public view
        returns (uint)
    {
        return seed;
    }

    function next()
        onlyDuring(State.Done)
        public
        returns (uint)
    {
        seed = uint(keccak256(abi.encodePacked(seed)));
        index++;
        emit LogRandomGenerated(index, seed);
        return seed;
    }
}
