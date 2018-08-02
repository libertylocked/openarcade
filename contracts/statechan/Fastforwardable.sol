pragma solidity 0.4.24;

import "./Serializable.sol";


// An abstract contract that supports state fastforward
// Note that the contract implementing this interface should check if
//  the state is forward (vs. backward) before setting the state
contract Fastforwardable is Serializable {
    bytes constant ETH_SIGN_PREFIX = "\x19Ethereum Signed Message:\n32";

    function requestFastforward(
        bytes cstate, bytes32[] rs, bytes32[] ss, uint8[] vs)
        external
    {
        // players must sign the hash of controller state
        address[] storage players = getPlayersStorage();
        require(
            /* solium-disable-next-line operator-whitespace */
            rs.length == players.length &&
            ss.length == players.length &&
            vs.length == players.length,
            "all players' signatures are required"
        );
        bytes32 cstateHash = keccak256(cstate);
        for (uint i = 0; i < players.length; i++) {
            require(
                recover(cstateHash, rs[i], ss[i], vs[i]) == players[i],
                "invalid signature"
            );
        }
        // all checks ok - set state
        require(deserialize(cstate), "fail to deserialize");
    }

    function recover(bytes32 message, bytes32 r, bytes32 s, uint8 v)
        internal pure returns (address)
    {
        return ecrecover(
            keccak256(abi.encodePacked(ETH_SIGN_PREFIX, message)), v, r, s);
    }

    function getPlayersStorage()
        internal view
        returns (address[] storage);
}
