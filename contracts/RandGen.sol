pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


// Random number generator using commit-reveal.
// This contract should be deployed by a controller. The controller
//  who is the owner serves as a relay to call commit/reveal
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
        Ready
    }

    event LogCommitted(address player, bytes32 commit);
    event LogRevealed(address player, uint number);
    event LogStateChanged(State state);
    event LogRandomGenerated(uint index, uint number);

    modifier onlyPlayer(address sender) {
        require(players[sender]);
        _;
    }

    modifier onlyNotCommitted(address sender) {
        require(commits[sender] == 0);
        _;
    }

    modifier onlyNotRevealed(address sender) {
        require(reveals[sender] == 0);
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

    function commit(address sender, bytes32 _hash)
        onlyOwner
        onlyDuring(State.Commit)
        external
        returns (bool)
    {
        return _commit(sender, _hash);
    }

    // function commitFromPlayer(bytes32 _hash)
    //     onlyPlayer(msg.sender)
    //     onlyDuring(State.Commit)
    //     external
    //     returns (bool)
    // {
    //     return _commit(msg.sender, _hash);
    // }

    function reveal(address sender, uint _num)
        onlyOwner
        onlyDuring(State.Reveal)
        external
        returns (bool)
    {
        return _reveal(sender, _num);
    }

    // function revealFromPlayer(uint _num)
    //     onlyPlayer(msg.sender)
    //     onlyDuring(State.Reveal)
    //     external
    //     returns (bool)
    // {
    //     return _reveal(msg.sender, _num);
    // }

    function next()
        onlyOwner
        onlyDuring(State.Ready)
        external
        returns (uint)
    {
        seed = uint(keccak256(abi.encodePacked(seed)));
        index++;
        emit LogRandomGenerated(index, seed);
        return seed;
    }

    function current()
        onlyDuring(State.Ready)
        external view
        returns (uint)
    {
        return seed;
    }

    /* Private functions */

    function _commit(address sender, bytes32 _hash)
        onlyPlayer(sender)
        onlyNotCommitted(sender)
        onlyDuring(State.Commit)
        private
        returns (bool)
    {
        // the commit can't be zero or hashed zero
        require(_hash != 0);
        require(_hash != keccak256(abi.encodePacked(uint(0))));
        commits[sender] = _hash;
        commitCount++;
        emit LogCommitted(sender, _hash);
        if (commitCount == playerCount) {
            state = State.Reveal;
            emit LogStateChanged(State.Reveal);
        }
        return true;
    }

    function _reveal(address sender, uint _num)
        onlyPlayer(sender)
        onlyNotRevealed(sender)
        onlyDuring(State.Reveal)
        private
        returns (bool)
    {
        // check commit
        require(keccak256(abi.encodePacked(_num)) == commits[sender]);
        reveals[sender] = _num;
        revealCount++;
        emit LogRevealed(sender, _num);
        seed ^= _num;
        if (revealCount == playerCount) {
            state = State.Ready;
            emit LogStateChanged(State.Ready);
        }
        return true;
    }

}
