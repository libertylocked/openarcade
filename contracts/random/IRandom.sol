pragma solidity 0.4.24;


interface IRandom {
    function next() external returns (uint);
    function request() external returns (bool);
    function current() external view returns (uint);
    function ready() external view returns (bool);
}
