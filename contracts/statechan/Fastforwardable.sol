pragma solidity 0.4.24;


// An abstract contract that supports state fastforward
contract Fastforwardable {
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
            "all players's sigs are required"
        );
        bytes32 cstateHash = keccak256(cstate);
        for (uint i = 0; i < players.length; i++) {
            require(recover(cstateHash, rs[i], ss[i], vs[i]) == players[i]);
        }
        // all checks ok - set state
        require(fastforward(cstate));
    }

    function encodeControllerState() external view returns (bytes);

    function recover(bytes32 message, bytes32 r, bytes32 s, uint8 v)
        private pure returns (address)
    {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, message));
        return ecrecover(prefixedHash, v, r, s);
    }

    function getPlayersStorage()
        private view
        returns (address[] storage);

    function fastforward(bytes cstate) private returns (bool);
}
