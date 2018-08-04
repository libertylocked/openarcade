pragma solidity 0.4.24;


interface IRandom {
    // next should return the next random number
    function next() external returns (uint);
    // request should request a new seed
    function request() external returns (bool);
    // current should return the last number returned by next.
    // if called before the first `next` call, it should return the seed of RNG
    function current() external view returns (uint);
    // index should return the index of the `current` from `seed`
    // zero index is the seed
    function index() external view returns (uint);
    // ready should return true if random numbers are available
    function ready() external view returns (bool);
}
