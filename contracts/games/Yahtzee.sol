pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../util/BytesUtil.sol";
import { YahtzeeConnect as Connect } from "../.generated/YahtzeeConnect.sol";


// Yahtzee game
// XXX this game requires some client side magic to work.
// Players will have to use client-side XRandom to see what values they roll,
// before sending a move to update the game state, where the values are
// actually obtained from random.next. Player sends 2 reroll picks, then a
// combination pick. Or, to stop rerolling sooner, player sends a zero mask,
// then a combination pick, in different txs. Either way, a move can either be
// a roll mask (incl. 0), or a comb pick, but not both.
library Yahtzee {
    using SafeMath for uint256;
    using BytesUtil for bytes;

    struct State {
        uint[] scoreCard;
        bool[] pickedCombos;
        uint rollsLeft;
        uint rollPick; // dices picked to reroll - only lowest 5 bits are used
        uint[5] dices;
    }

    struct Action {
        uint rollPick; // only lowest 5 bits are used
        Combination combPick;
    }

    // A total of 12 combinations
    enum Combination {
        Ones,
        Twos,
        Threes,
        Fours,
        Fives,
        ThreeOfAKind,
        FourOfAKind,
        FullHouse,
        SmallStraight,
        LargeStraight,
        Chance,
        Yahtzee
    }

    /* Internal functions */

    function init(
        State storage state, Connect.Tools storage /*tools*/,
        uint playerCount, bytes /*initParams*/)
        internal
        returns (uint)
    {
        state.scoreCard = new uint[](playerCount * 12);
        state.pickedCombos = new bool[](playerCount * 12);
        state.rollPick = 31;
        state.rollsLeft = 3;
        return 1;
    }

    function next(State storage state, Connect.Info storage info)
        internal view
        returns (uint)
    {
        // alternate if no rolls left
        if (state.rollsLeft == 0) {
            return (info.control % info.playerCount).add(1);
        }
        // otherwise the same player
        return info.control;
    }

    function update(
        State storage state, Connect.Tools storage tools,
        Connect.Info storage info, Connect.Input memory input)
        internal
    {
        // consume roll
        state.rollsLeft = state.rollsLeft.sub(1);
        // use previous mask to roll
        if (state.rollPick & 1 == 1) {
            state.dices[0] = tools.random.next();
        }
        if ((state.rollPick >> 1) & 1 == 1) {
            state.dices[1] = tools.random.next();
        }
        if ((state.rollPick >> 2) & 1 == 1) {
            state.dices[2] = tools.random.next();
        }
        if ((state.rollPick >> 3) & 1 == 1) {
            state.dices[3] = tools.random.next();
        }
        if ((state.rollPick >> 4) & 1 == 1) {
            state.dices[4] = tools.random.next();
        }
        // if no dice is picked to roll, end the turn
        if (state.rollPick == 0) {
            state.rollsLeft = 0;
        }
        // if turn is zero, player's input must be a combination
        if (state.rollsLeft == 0) {
            Combination comb = input.action.combPick;
            uint cidx = (input.pid - 1) * 12 + uint(comb);
            // mark combo picked
            state.pickedCombos[cidx] = true;
            // calculate combo score
            state.scoreCard[cidx] = calcComboScore(state, input.pid, comb);
        } else {
            // set mask for next roll
            state.rollPick = input.action.rollPick;
        }
    }

    function legal(
        State storage state, Connect.Info storage info,
        Connect.Input memory input)
        internal view
        returns (bool)
    {
        // TODO
        if (info.control != input.pid) {
            return false;
        }
        if (input.action.rollPick > 31) {
            return false;
        }
        // After 2 rerolls rollsLeft would be 1. This is is when combination
        // pick is expected. Player should not reroll at this state
        if (state.rollsLeft == 1) {
            if (input.action.rollPick != 0) {
                return false;
            }
            // the combination cannot have already been picked
            if (state.pickedCombos[(input.pid - 1) * 12 + uint(input.action.combPick)]) {
                return false;
            }
        }
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

    function decodeAction(bytes s)
        internal pure
        returns (Action)
    {
        return Action({
            rollPick: s.sliceUint(0),
            combPick: Combination(s.sliceUint(32))
        });
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

    /* Private functions */

    function calcComboScore(State storage state, uint pid, Combination combo)
        private
        returns (uint)
    {
        // TODO
        return 0;
    }
}
