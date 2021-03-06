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

    event LogInit(uint initialControl);

    constructor(uint playerCount, IRandom random) public {
        info = Connect.Info({
            playerCount: playerCount,
            turn: 1,
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
        uint initControl = Connect.init(state, tools,
            info.playerCount, initParams);
        info.control = initControl;
        emit LogInit(initControl);
        return initControl;
    }

    function next()
        external view
        returns (uint)
    {
        uint nextPid = Connect.next(state, info);
        return nextPid;
    }

    function update(uint pid, bytes action)
        external
    {
        Connect.Input memory input = Connect.Input({
            pid: pid,
            action: Connect.decodeAction(action)
        });
        Connect.update(state, tools, info, input);
        info.turn++;
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

    // Below functions are not part of Connect, but included to make testing easier
    // This function replaces the RNG
    function setRandom(IRandom random)
        external
    {
        tools.random = random;
    }

    function setInfo(uint playerCount, uint turn, uint control)
        external
    {
        info.playerCount = playerCount;
        info.turn = turn;
        info.control = control;
    }

    function control()
        external view
        returns (uint)
    {
        return info.control;
    }
}
