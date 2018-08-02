pragma solidity 0.4.24;

import "../random/RXRandom.sol";


// This mock is used to test deserialization in RXRandom
contract RXRandomDeserializeMock is RXRandom {
    function deserializeExternal(bytes data)
        external
    {
        require(deserialize(data));
    }
}
