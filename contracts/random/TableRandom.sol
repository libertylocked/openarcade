pragma solidity 0.4.24;

import "./IRandom.sol";

// Classic DOOM style random table
contract TableRandom is IRandom {
    uint[] public rndTable;
    uint index;

    constructor(uint[] numbers) public {
        require(numbers.length > 0);
        rndTable = numbers;
    }

    function next() external returns (uint) {
        uint n = rndTable[index];
        index = (index + 1) % rndTable.length;
        return n;
    }

    function request() external returns (bool) {
        index = 0;
    }

    function current() external view returns (uint) {
        return rndTable[index];
    }

    function ready() external view returns (bool){
        return true;
    }
}
