pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../util/BytesUtil.sol";
// TODO: Edit this line for your game! e.g. MyGameConnect
import { StarterConnect as Connect } from "../.generated/StarterConnect.sol";


library Starter {
    using SafeMath for uint256;
    using BytesUtil for bytes;

    struct State {
        // TODO - define your game state here
    }

    struct Action {
        // TODO - define player action here
    }

    /* Internal functions */

    function init(
        State storage /*state*/, Connect.Tools storage /*tools*/,
        uint /*playerCount*/, bytes /*initParams*/)
        internal
        returns (uint)
    {
        // TODO
        return 0;
    }

    function next(State storage /*state*/, Connect.Info storage /*info*/)
        internal view
        returns (uint)
    {
        // TODO
        return 0;
    }

    function update(
        State storage /*state*/, Connect.Tools storage /*tools*/,
        Connect.Info storage /*info*/, Connect.Input memory /*input*/)
        internal
    {
        // TODO
    }

    function legal(
        State storage /*state*/, Connect.Info storage /*info*/,
        Connect.Input memory /*input*/)
        internal view
        returns (bool)
    {
        // TODO
        return true;
    }

    function terminal(State storage /*state*/, Connect.Info storage /*info*/)
        internal view
        returns (bool)
    {
        // TODO
        return false;
    }

    function goal(
        State storage /*state*/, Connect.Info storage /*info*/, uint /*pid*/)
        internal view
        returns (uint)
    {
        // TODO
        return 0;
    }

    function decodeAction(bytes /*s*/)
        internal pure
        returns (Action)
    {
        // TODO
        return Action();
    }

    function encodeState(State storage /*state*/)
        internal view
        returns (bytes)
    {
        // TODO
        return new bytes(0);
    }

    function setState(State storage /*state*/, bytes /*encodedState*/)
        internal
    {
        // TODO
        return;
    }
}
