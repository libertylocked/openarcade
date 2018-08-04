pragma solidity 0.4.24;


// Serializable is an abstract contract that makes it serializable for state
// channel support.
contract Serializable {
    // Serilize the state of the contract.
    // The function is external - it should be called client side to snapshot
    // the state
    function serialize() external view returns (bytes);

    // Deserializes the state of the contract.
    // The contract should parse the encoded data, and apply it to the current
    // state. Note that a contract that's only fastforwardable can fail on
    // backward changes.
    function deserialize(bytes data) internal;
}
