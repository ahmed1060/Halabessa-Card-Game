"use strict";

// Server-side counterpart to lib/features/game/domain/logic/game_engine.dart.
// It intentionally works only with plain JSON so Cloud Functions can apply a
// move without ever trusting a client-supplied replacement MatchState.

const SUITS = ["hearts", "diamonds", "clubs", "spades"];
const RANKS = ["two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "jack", "queen", "king", "ace"];

function cardKey(card) {
  return `${card.suit}_${card.rank}`;
}

function assertCard(card) {
  if (!card || !SUITS.includes(card.suit) || !RANKS.includes(card.rank)) {
    throw new Error("Invalid card.");
  }
}

function standardDeck() {
  return SUITS.flatMap((suit) => RANKS.map((rank) => ({ suit, rank })));
}

function shuffleDeck(deck, randomInt) {
  const next = [...deck];
  for (let index = next.length - 1; index > 0; index--) {
    const swapIndex = randomInt(index + 1);
    [next[index], next[swapIndex]] = [next[swapIndex], next[index]];
  }
  return next;
}

function startRound(state, playerId, randomInt) {
  if (!Array.isArray(state.playerIds) || state.playerIds.length !== 4 || state.playerIds.some((id) => id.startsWith("waiting_"))) {
    throw new Error("A full match is required to start a round.");
  }
  if (state.playerIds[0] !== playerId) throw new Error("Only the room host can start a round.");
  if (!["waitingForPlayers", "shuffleVoting", "rematchVoting", "roundScoring"].includes(state.phase)) {
    throw new Error("Match is not ready to start a round.");
  }
  const deck = shuffleDeck(standardDeck(), randomInt);
  const firstRound = !Number.isInteger(state.roundCount) || state.roundCount < 1;
  const dealerIndex = firstRound ? 0 : (state.dealerIndex + 1) % state.playerIds.length;
  return {
    state: {
      ...state,
      dealerIndex,
      currentTurnIndex: (dealerIndex + 1) % state.playerIds.length,
      phase: "preRoundCut",
      roundCount: firstRound ? 1 : state.roundCount + 1,
      roundsSinceLastShuffle: 0,
      board: [], handCards: {}, harvestStacks: { teamA: [], teamB: [] },
      shuffleVotes: {}, rematchVotes: {}, botInjectionVotes: {}, recentFasha: [],
      cardOwnership: {}, skippedMatches: {}, cutLastCard: null, lastCaptureTeam: null,
      deckCount: deck.length,
    },
    deck,
  };
}

function cutDeck(deck, position) {
  if (!Number.isInteger(position) || position <= 0 || position >= deck.length) return [...deck];
  return [...deck.slice(position), ...deck.slice(0, position)];
}

function cut(state, deck, playerId, position) {
  if (state.phase !== "preRoundCut") throw new Error("Match is not ready to cut.");
  if (!Array.isArray(state.playerIds) || state.playerIds.length !== 4) throw new Error("A match needs four players.");
  const cutterIndex = (state.dealerIndex + state.playerIds.length - 1) % state.playerIds.length;
  if (state.playerIds[cutterIndex] !== playerId) throw new Error("Only the cutter can cut.");
  const nextDeck = cutDeck(deck, position);
  return {
    state: {
      ...state,
      deckCount: nextDeck.length,
      phase: "dealingFasha",
      cutLastCard: nextDeck[0] || null,
    },
    deck: nextDeck,
  };
}

function draw(deck) {
  if (deck.length === 0) return [null, deck];
  return [deck[deck.length - 1], deck.slice(0, -1)];
}

function deal(state, deck, playerId, { initial }) {
  if (!Array.isArray(state.playerIds) || state.playerIds.length !== 4) throw new Error("A match needs four players.");
  if (state.playerIds[state.dealerIndex] !== playerId) throw new Error("Only the dealer can deal.");
  if (initial ? state.phase !== "dealingFasha" : state.phase !== "playing") {
    throw new Error("Match is not ready to deal.");
  }
  if (!initial && !state.playerIds.every((id) => (state.handCards?.[id] || []).length === 0)) {
    throw new Error("Cards remain in players' hands.");
  }
  const requiredCards = initial ? 20 : 16;
  if (!Array.isArray(deck) || deck.length < requiredCards) throw new Error("Not enough cards to deal.");
  const keys = new Set();
  for (const card of deck) {
    assertCard(card);
    if (keys.has(cardKey(card))) throw new Error("Deck contains duplicate cards.");
    keys.add(cardKey(card));
  }
  let remaining = [...deck];
  const board = initial ? [] : [...(state.board || [])];
  const hands = { ...(state.handCards || {}) };
  if (initial) {
    for (let i = 0; i < 4; i++) {
      const [card, next] = draw(remaining);
      remaining = next;
      if (card) board.push(card);
    }
  }
  for (const playerId of state.playerIds) {
    const hand = initial ? [] : [...(hands[playerId] || [])];
    for (let i = 0; i < 4; i++) {
      const [card, next] = draw(remaining);
      remaining = next;
      if (card) hand.push(card);
    }
    hands[playerId] = hand;
  }
  return {
    state: {
      ...state,
      board,
      handCards: hands,
      deckCount: remaining.length,
      recentFasha: initial ? [...board] : (state.recentFasha || []),
      handInRound: initial ? 1 : (state.handInRound || 0) + 1,
      phase: initial ? "dealingCards" : "playing",
      ...(initial ? {} : { turnStartTime: new Date().toISOString() }),
    },
    deck: remaining,
  };
}

function playCard(state, playerId, card) {
  assertCard(card);
  if (state.phase !== "playing") throw new Error("Match is not accepting cards.");
  if (state.playerIds?.[state.currentTurnIndex] !== playerId) throw new Error("It is not your turn.");
  const hands = { ...(state.handCards || {}) };
  const hand = [...(hands[playerId] || [])];
  const index = hand.findIndex((candidate) => cardKey(candidate) === cardKey(card));
  if (index === -1) throw new Error("Card is not in your hand.");
  hand.splice(index, 1);
  hands[playerId] = hand;

  const board = [...(state.board || [])];
  const ownership = { ...(state.cardOwnership || {}) };
  const skipped = { ...(state.skippedMatches || {}) };
  const nextTurn = (state.currentTurnIndex + 1) % state.playerIds.length;
  const top = board[board.length - 1];
  if (top && hand.some((candidate) => candidate.rank === top.rank) && card.rank !== top.rank) {
    const skip = `${top.rank}:${ownership[cardKey(top)] || "fasha"}`;
    skipped[playerId] = [...new Set([...(skipped[playerId] || []), skip])];
  }
  if (!top || top.rank !== card.rank) {
    board.push(card);
    ownership[cardKey(card)] = playerId;
    return {
      ...state,
      board,
      handCards: hands,
      cardOwnership: ownership,
      skippedMatches: skipped,
      currentTurnIndex: nextTurn,
      turnStartTime: new Date().toISOString(),
    };
  }

  const team = state.playerIds.indexOf(playerId) % 2 === 0 ? "teamA" : "teamB";
  let points = 1;
  const emojis = { ...(state.playerEmojis || {}) };
  if (state.mode === "tafweet") {
    const playerSkips = [...(skipped[playerId] || [])];
    const previousId = state.playerIds[(state.currentTurnIndex + state.playerIds.length - 1) % state.playerIds.length];
    const rankPrefix = `${card.rank}:`;
    const fasha = playerSkips.includes(`${rankPrefix}fasha`);
    const standard = playerSkips.includes(`${rankPrefix}${previousId}`);
    const double = playerSkips.filter((skip) => skip.startsWith(rankPrefix)).length >= 2 && standard;
    if (fasha) {
      points += 5;
      emojis[playerId] = "😎";
      skipped[playerId] = playerSkips.filter((skip) => skip !== `${rankPrefix}fasha`);
    } else if (double) {
      points += 10;
      emojis[playerId] = "🔥";
      skipped[playerId] = playerSkips.filter((skip) => !skip.startsWith(rankPrefix));
    } else if (standard) {
      points += 5;
      emojis[playerId] = "😂";
      skipped[playerId] = playerSkips.filter((skip) => !skip.startsWith(rankPrefix));
    }
  }
  const harvest = { ...(state.harvestStacks || {}) };
  harvest[team] = [...(harvest[team] || []), { leadingCard: card, capturedCards: board }];
  return {
    ...state,
    board: [],
    handCards: hands,
    harvestStacks: harvest,
    skippedMatches: skipped,
    playerEmojis: emojis,
    currentTurnIndex: nextTurn,
    teamAScore: (state.teamAScore || 0) + (team === "teamA" ? points : 0),
    teamBScore: (state.teamBScore || 0) + (team === "teamB" ? points : 0),
    lastCaptureTeam: team,
    turnStartTime: new Date().toISOString(),
  };
}

module.exports = { cardKey, standardDeck, shuffleDeck, startRound, cutDeck, cut, deal, playCard };
