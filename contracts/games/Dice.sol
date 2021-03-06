pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../util/BytesUtil.sol";
import { DiceConnect as Connect } from "../.generated/DiceConnect.sol";


// Dice is a pretty contrived example to show how RNG reset works
library Dice {
    using SafeMath for uint256;
    using BytesUtil for bytes;

    struct State {
        uint roundsLeft;
        uint[] score; // index 0 is unused
    }

    struct Action {
        // player can choose to roll or give up
        uint roll;
    }

    event LogRoll(uint pid, uint roll);

    /* Internal functions */

    function init(
        State storage state, Connect.Tools storage /*tools*/,
        uint playerCount, bytes initParams)
        internal
        returns (uint)
    {
        state.score = new uint[](playerCount + 1);
        state.roundsLeft = initParams.sliceUint(0);
        // start the game with player 1 in control
        return 1;
    }

    function next(State storage /*state*/, Connect.Info storage info)
        internal view
        returns (uint)
    {
        return (info.control % info.playerCount).add(1);
    }

    function update(
        State storage state, Connect.Tools storage tools,
        Connect.Info storage info, Connect.Input memory input)
        internal
    {
        // it's guaranteed that update will be executed when RNG is in ready state
        if (input.action.roll == 1) {
            uint prevScore = state.score[input.pid];
            uint roll = (tools.random.next() % 6).add(1);
            emit LogRoll(input.pid, roll);
            state.score[input.pid] = prevScore.add(roll);
            // Request new randomness for the next round
            // XXX this means player is able to see the seed before input is sent
            tools.random.request();
        }
        // if we are at the last player in current round, go to next round
        if (input.pid == info.playerCount) {
            state.roundsLeft--;
        }
    }

    function legal(
        State storage /*state*/, Connect.Info storage info,
        Connect.Input memory input)
        internal view
        returns (bool)
    {
        // player can only play in his/her turn
        if (info.control != input.pid) {
            return false;
        }
        return true;
    }

    function terminal(
        State storage state, Connect.Info storage /*info*/)
        internal view
        returns (bool)
    {
        return state.roundsLeft == 0;
    }

    function goal(
        State storage state, Connect.Info storage /*info*/, uint pid)
        internal view
        returns (uint)
    {
        return state.score[pid];
    }

    function decodeAction(bytes s)
        internal pure
        returns (Action)
    {
        return Action({
            roll: s.sliceUint(0)
        });
    }

    function encodeState(State storage state)
        internal view
        returns (bytes)
    {
        // Because index 0 in score array is unused, we can put roundsLeft in
        // it and do abi encode packed on this dynamic sized array.
        // So the packed byte arr would be like
        // [roundsLeft, player1Score, player2Score, ...]
        uint[] memory data = new uint[](state.score.length);
        data[0] = state.roundsLeft;
        for (uint i = 1; i < state.score.length; i++) {
            data[i] = state.score[i];
        }
        return abi.encodePacked(data);
    }

    function setState(State storage state, bytes encodedState)
        internal
    {
        uint[] memory data = encodedState.toUintArray();
        state.roundsLeft = data[0];
        uint[] memory score = new uint[](data.length);
        for (uint i = 1; i < data.length; i++) {
            score[i] = data[i];
        }
        state.score = score;
    }

    /* External functions */

    function encodeAction(bool play)
        external pure
        returns (bytes)
    {
        return abi.encode(play);
    }
}
