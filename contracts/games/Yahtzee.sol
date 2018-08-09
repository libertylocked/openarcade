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
        uint[] pickedCombos; // boolean flags for combos already picked
        uint rollsLeft;
        uint rollPick; // dices picked to reroll - only lowest 5 bits are used
        uint[5] dices;
    }

    struct Action {
        uint rollPick; // only lowest 5 bits are used
        Combination combPick;
    }

    // A total of 13 combinations
    enum Combination {
        Ones,
        Twos,
        Threes,
        Fours,
        Fives,
        Sixes,
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
        state.scoreCard = new uint[](playerCount * 13);
        state.pickedCombos = new uint[](playerCount * 13);
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
        Connect.Info storage /*info*/, Connect.Input memory input)
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
            uint cidx = (input.pid - 1) * 13 + uint(comb);
            // mark combo picked
            state.pickedCombos[cidx] = 1;
            // calculate combo score
            state.scoreCard[cidx] = calcComboScore(state.dices, comb);
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
            if (state.pickedCombos[
                (input.pid - 1) * 13 + uint(input.action.combPick)] == 1) {
                return false;
            }
        }
        return true;
    }

    function terminal(State storage state, Connect.Info storage /*info*/)
        internal view
        returns (bool)
    {
        // game ends when all the combos are used (by all players)
        for (uint i = 0; i < state.pickedCombos.length; ++i) {
            if (state.pickedCombos[i] == 0) {
                return false;
            }
        }
        return true;
    }

    function goal(
        State storage state, Connect.Info storage /*info*/, uint pid)
        internal view
        returns (uint)
    {
        // get the sum of the player's score card
        uint sumScore = 0;
        for (uint i = 0; i < 13; ++i) {
            sumScore += state.scoreCard[(pid - 1) * 13 + i];
        }
        return sumScore;
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

    function encodeState(State storage state)
        internal view
        returns (bytes)
    {
        return abi.encodePacked(
            state.scoreCard.length, state.scoreCard, state.pickedCombos,
            state.rollsLeft, state.rollPick, state.dices
        );
    }

    function setState(State storage state, bytes encodedState)
        internal
    {
        uint sz = encodedState.sliceUint(0);
        state.scoreCard = encodedState.sliceUintArray(32, sz);
        state.pickedCombos = encodedState.sliceUintArray(32 + sz * 32, sz);
        state.rollsLeft = encodedState.sliceUint(32 + sz * 64);
        state.rollPick = encodedState.sliceUint(64 + sz * 64);
        uint[] memory dices = encodedState.sliceUintArray(96 + sz * 64, 5);
        for (uint i = 0; i < 5; ++i) {
            state.dices[i] = dices[i];
        }
    }

    /* Private functions */

    function calcComboScore(uint[5] storage dices, Combination combo)
        private view
        returns (uint)
    {
        uint score = 0;
        uint[7] memory counter;
        for (uint i = 0; i < 5; ++i) {
            counter[dices[i]] += 1;
        }

        if (combo == Combination.Ones) {
            for (i = 0; i < 5; ++i) {
                if (dices[i] == 1) {
                    score += 1;
                }
            }
        } else if (combo == Combination.Twos) {
            for (i = 0; i < 5; ++i) {
                if (dices[i] == 2) {
                    score += 1;
                }
                score *= 2;
            }
        } else if (combo == Combination.Threes) {
            for (i = 0; i < 5; ++i) {
                if (dices[i] == 3) {
                    score += 1;
                }
                score *= 3;
            }
        } else if (combo == Combination.Fours) {
            for (i = 0; i < 5; ++i) {
                if (dices[i] == 4) {
                    score += 1;
                }
                score *= 4;
            }
        } else if (combo == Combination.Fives) {
            for (i = 0; i < 5; ++i) {
                if (dices[i] == 5) {
                    score += 1;
                }
                score *= 5;
            }
        } else if (combo == Combination.Sixes) {
            for (i = 0; i < 5; ++i) {
                if (dices[i] == 6) {
                    score += 1;
                }
                score *= 6;
            }
        } else if (combo == Combination.ThreeOfAKind) {
            for (i = 1; i < 7; ++i) {
                if (counter[i] >= 3) {
                    for (i = 0; i < 5; ++i) {
                        score += dices[i];
                    }
                    break;
                }
            }
        } else if (combo == Combination.FourOfAKind) {
            for (i = 1; i < 7; ++i) {
                if (counter[i] >= 4) {
                    for (i = 0; i < 5; ++i) {
                        score += dices[i];
                    }
                    break;
                }
            }
        } else if (combo == Combination.FullHouse) {
            uint threeAndTwo = 0;
            for (i = 1; i < 7; ++i) {
                if (counter[i] == 3) {
                    threeAndTwo |= 1;
                } else if (counter[i] == 2) {
                    threeAndTwo |= 1 << 1;
                }
            }
            if (threeAndTwo == 3) {
                score += 25;
            }
        } else if (combo == Combination.SmallStraight) {
            for (i = 1; i < 4; ++i) {
                /* solium-disable-next-line operator-whitespace */
                if (counter[i] > 0 &&
                    counter[i + 1] > 0 &&
                    counter[i + 2] > 0 &&
                    counter[i + 3] > 0) {
                    score += 30;
                    break;
                }
            }
        } else if (combo == Combination.LargeStraight) {
            for (i = 1; i < 3; ++i) {
                /* solium-disable-next-line operator-whitespace */
                if (counter[i] > 0 &&
                    counter[i + 1] > 0 &&
                    counter[i + 2] > 0 &&
                    counter[i + 3] > 0 &&
                    counter[i + 4] > 0) {
                    score += 40;
                    break;
                }
            }
        } else if (combo == Combination.Chance) {
            for (i = 0; i < 5; ++i) {
                score += dices[i];
            }
        } else if (combo == Combination.Yahtzee) {
            for (i = 1; i < 7; ++i) {
                if (counter[i] == 5) {
                    score += 50;
                    break;
                }
            }
        }
        return score;
    }
}
