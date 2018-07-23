pragma solidity 0.4.24;

import "truffle/Assert.sol";
import "../../contracts/random/TableRandom.sol";


contract TestTableRandom {
    function testNext1() external {
        uint[] memory table = new uint[](3);
        table[0] = 1;
        table[1] = 2;
        table[2] = 3;
        TableRandom random = new TableRandom(table);
        Assert.equal(random.next(), 2, "first next should be 2");
        Assert.equal(random.next(), 3, "second next should be 3");
        Assert.equal(random.next(), 1, "third next should be 1");
    }
}
