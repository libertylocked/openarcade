pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../util/BytesUtil.sol";
import { MMMConnect as Connect } from "../.generated/MMMConnect.sol";


// MMM is the Mau Mau Minus game library
library MMM {
    using SafeMath for uint256;
    using BytesUtil for bytes;

    struct State {
        uint[] deck;
        uint prevSuit;
        uint prevValue;
        uint cardCount;
        uint[] stack;
    }

    struct Action {
        uint card;
        uint drawOrSkip; // 0 play, 1 draw, 2 skip
    }

    /* Internal functions */

    function init(State storage state, Connect.Tools storage tools, uint playerCount)
        internal
        returns (uint)
    {

        state.cardCount = playerCountToCardCount(playerCount);

        state.stack = new uint[](state.cardCount);
        state.deck = new uint[](state.cardCount);

        for (uint i = 0; i < state.cardCount; ++i) {
            state.stack[i] = i;
        }

        for (uint player = 1; player <= playerCount; ++player) {
            for (uint card = 0; card < 5; ++card) {
                uint index = tools.random.next() % state.cardCount;
                state.stack[index] = state.stack[--state.cardCount];
                state.deck[state.stack[index]] = player;
            }
        }

        uint initCard = state.stack[state.cardCount - 1];
        (state.prevSuit, state.prevValue) = decodeCard(initCard);

        // start the game with control setting to random
        // since player ID starts at 0, for a 2 player game it would be 1 or 2
        uint initialControl = 1 + tools.random.next() % playerCount;
        // since all cells are initialized to zero, no state modification is needed
        return initialControl;
    }

    function next(State storage state, Connect.Info storage info)
        internal view
        returns (uint)
    {
        // In MMM simply alternate
        return 1 + info.control % info.playerCount;
    }

    function update(State storage state, Connect.Tools storage tools, Connect.Info storage info, Connect.Input memory input)
        internal
    {
        // in MMM only one cell is updated
        Action memory action = input.action;
        if (action.drawOrSkip == 1) {
            uint index = tools.random.next() % state.cardCount;
            state.stack[index] = state.stack[--state.cardCount];
            state.deck[state.stack[index]] = input.pid;
        } else if (action.drawOrSkip != 2) {
            state.deck[action.card] = 0;
            (state.prevSuit, state.prevValue) = decodeCard(action.card);
            state.prevSuit = normalizeSuit(state.prevSuit);
        }
    }

    function legal(State storage state, Connect.Info storage info, Connect.Input memory input)
        internal view
        returns (bool)
    {
        // player can only play in his/her turn
        if (info.control != input.pid) {
            return false;
        }

        // xy must not be out of range
        if (input.action.card < 0 || input.action.card >= state.deck.length) {
            if (input.action.drawOrSkip == 2 || (input.action.drawOrSkip == 1 && state.cardCount > 0)) {
                return true;
            }
            return false;
        }

        // must place on empty spot
        if (state.deck[input.action.card] != info.control) {
            return false;
        }

        return true;
    }

    function terminal(State storage state, Connect.Info storage info)
        internal view
        returns (bool)
    {
        if (nobodyHasCardToPlay(state, info)) {
            return true;
        }

        if (checkWinner(state, info) != 0) {
            return true;
        }

        return false;
    }

    function goal(State storage state, Connect.Info storage info, uint pid)
        internal view
        returns (uint)
    {
        if (nobodyHasCardToPlay(state, info)) {
            // if board is full, both players get 50 points
            return 50;
        }
        uint winnerID = checkWinner(state, info);
        if (winnerID == pid) {
            return 100;
        } else {
            return 0;
        }
    }

    function decodeAction(bytes s)
        internal pure
        returns (Action)
    {
        uint[] memory res = s.sliceUints(0, 2);
        return Action({
            card: res[0],
            drawOrSkip: res[1]
        });
    }

    /* External functions */

    function encodeAction(uint x, uint y)
        external pure
        returns (bytes)
    {
        return abi.encode(x, y);
    }

    /* Private functions */

    function checkWinner(State storage state, Connect.Info storage info)
        private view
        returns (uint)
    {
        bool[] memory players = new bool[](info.playerCount + 1);

        uint maxCardNumber = state.deck.length;

        for (uint card = 0; card < maxCardNumber; ++card) {
            players[state.deck[card]] = true;
        }

        for (uint player = 1; player <= info.playerCount; ++player) {
            if (!players[player]) {
                return player;
            }
        }

        return 0;
    }

    function playerCountToCardCount(uint playerCount)
        private pure
        returns (uint)
    {
        return 52 * (1 + uint(playerCount / 5));
    }

    function decodeCard(uint _card)
        private pure
        returns (uint, uint)
    {
        return ((1 + uint(_card / 13)), (1 + uint(_card % 13)));
    }

    function hasCardToPlay(State storage state, uint pid)
        private view
        returns (bool)
    {
        for (uint card = 0; card < state.deck.length; ++card) {
            uint suit = 0;
            uint value = 0;
            (suit, value) = decodeCard(card);
            if (state.deck[card] == pid) {
                if (normalizeSuit(suit) == state.prevSuit || value == state.prevValue) {
                    return true;
                }
            }
        }

        return false;
    }

    function nobodyHasCardToPlay(State storage state, Connect.Info storage info)
        private view
        returns (bool)
    {
        if (state.cardCount > 0) {
            return false;
        }

        for (uint pid = 1; pid <= info.playerCount; ++pid) {
            if (hasCardToPlay(state, pid)) {
                return false;
            }
        }

        return true;
    }

    function normalizeSuit(uint _color)
        private pure
        returns (uint)
    {
        uint color = _color;
        if (color % 4 == 0 && color != 0) {
            color = 4;
        } else {
            color %= 4;
        }
        return color;
    }
}
