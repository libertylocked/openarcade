pragma solidity 0.4.24;

import "./RXRandom.sol";
import "../statechan/Serializable.sol";


contract SerializableRXRandom is Serializable, RXRandom {
    constructor(address[] _players, address _relayer)
        public
        RXRandom(_players, _relayer)
    { }

    /**
     * @dev Serializes the current state of the RXRandom to bytes
     * @return The current state of RXRandom encoded to bytes
     */
    function serialize()
        external view
        returns (bytes)
    {
        bytes32[] memory commitsArr = new bytes32[](playersArray.length);
        for (uint i = 0; i < playersArray.length; ++i) {
            commitsArr[i] = commits[playersArray[i]];
        }
        return abi.encodePacked(uint(state), ringTurn, seed, current, index,
            roundNeg2CommitCount, roundNeg1CommitCount, commitsArr);
    }

    /**
     * @dev Sets the contract state by deserializing an encoded state. This is
     * only callable by the owner, which typically is a smart contract.
     * @param data The encoded state to set to
     * @return True if deserialization is successful
     */
    function deserializeByOwner(bytes data)
        external
        onlyOwner
    {
        deserialize(data);
    }

    function deserialize(bytes data)
        internal
    {
        uint[] memory s = data.toUintArray();
        // check size
        // the encoded data must be exact size
        require(
            s.length == 7 + playersArray.length,
            "encoded state is not of the correct length"
        );
        state = State(s[0]);
        ringTurn = s[1];
        seed = s[2];
        current = s[3];
        index = s[4];
        roundNeg2CommitCount = s[5];
        roundNeg1CommitCount = s[6];
        // restore commits and reveals
        for (uint i = 0; i < playersArray.length; ++i) {
            commits[playersArray[i]] = bytes32(s[7+i]);
        }
    }
}
