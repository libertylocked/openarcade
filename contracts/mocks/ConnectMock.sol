pragma solidity 0.4.24;

import "../Connect.sol";
import "../TTTGame.sol";
import "../random/IRandom.sol";


// This contract exposes a few functions of Connect so we we can easily test
// the game logic without having to deploy an entire controller.
contract ConnectMock {
    Game.State state;
    Connect.Info info;
    Connect.Tools tools;

    constructor(uint playerCount, IRandom random) public {
        info = Connect.Info({
            playerCount: playerCount,
            control: 0
        });
        tools = Connect.Tools({
            random: random
        });
    }

    function init(bytes initParams)
        external
        returns (uint)
    {
        uint initialControl = Connect.init(state, tools, info.playerCount, initParams);
        info.control = initialControl;
        return initialControl;
    }

    function next()
        external view
        returns (uint)
    {
        return Connect.next(state, info);
    }

    function update(uint pid, bytes action)
        external
    {
        Connect.Input memory input = Connect.Input({
            pid: pid,
            action: Connect.decodeAction(action)
        });
        Connect.update(state, tools, info, input);
    }

    function legal(uint pid, bytes action)
        external view
        returns (bool)
    {
        Connect.Input memory input = Connect.Input({
            pid: pid,
            action: Connect.decodeAction(action)
        });
        return Connect.legal(state, info, input);
    }

    function terminal()
        external view
        returns (bool)
    {
        return Connect.terminal(state, info);
    }

    function goal(uint pid)
        external view
        returns (uint)
    {
        return Connect.goal(state, info, pid);
    }

    function encodeState()
        external view
        returns (bytes)
    {
        return Connect.encodeState(state);
    }

    function setState(bytes encodedState)
        external
    {
        return Game.setState(state, encodedState);
    }
}
