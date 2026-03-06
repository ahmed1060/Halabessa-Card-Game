const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();

exports.validateMove = onRequest(async (req, res) => {
    const { matchId, playerId, playedCard, board, mode } = req.body;

    if (!board || board.length === 0) {
        return res.json({ valid: true, captured: [] });
    }

    const topCard = board[board.length - 1];
    const isMatch = (playedCard.rank === topCard.rank || playedCard.rank === 'JACK' || (playedCard.rank === 'SEVEN' && playedCard.suit === 'DIAMONDS'));

    if (mode === 'TAFWEET') {
        // In Tafweet, matching is usually "bad" or has different scoring.
        // For now, we capture but flag it differently for scoring logic.
        return res.json({
            valid: true,
            captured: isMatch ? [...board, playedCard] : [],
            isBasra: isMatch && board.length > 0,
            mode: 'TAFWEET'
        });
    }

    if (isMatch) {
        const captured = [...board, playedCard];
        return res.json({ valid: true, captured: captured, isBasra: board.length > 0 });
    }

    return res.json({ valid: true, captured: [] });
});

exports.dealCards = onRequest(async (req, res) => {
    const { playerIds, matchId, isInitialDeal } = req.body;

    if (!playerIds || playerIds.length !== 4) {
        return res.status(400).send("Require 4 players for Halabessa");
    }

    const suits = ['HEARTS', 'DIAMONDS', 'CLUBS', 'SPADES'];
    const ranks = ['TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE', 'TEN', 'JACK', 'QUEEN', 'KING', 'ACE'];

    let deck = [];
    if (isInitialDeal) {
        suits.forEach(s => ranks.forEach(r => deck.push({ id: `${r}_${s}`, rank: r, suit: s })));
        // Fisher-Yates Shuffle
        for (let i = deck.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [deck[i], deck[j]] = [deck[j], deck[i]];
        }
    } else {
        deck = req.body.remainingCards || [];
    }

    const hands = {};
    const dealOffset = isInitialDeal ? 4 : 0;

    playerIds.forEach((id, index) => {
        hands[id] = deck.slice(dealOffset + (index * 4), dealOffset + 4 + (index * 4));
    });

    const board = isInitialDeal ? deck.slice(0, 4) : [];
    const remaining = deck.slice(dealOffset + 16);

    res.json({
        board,
        hands,
        remaining,
        isGameOver: remaining.length === 0 && isInitialDeal === false
    });
});
