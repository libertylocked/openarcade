pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


contract Relayable is Ownable {
    address public relayer;

    constructor(address _relayer) public {
        relayer = _relayer;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "sender must be relayer");
        _;
    }

    function setRelayer(address _newRelayer) public onlyOwner {
        relayer = _newRelayer;
    }
}
