"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { standardDeck, startRound, cutDeck, cut, deal, playCard } = require("../match_engine");

test("deal distributes four cards to each player and four to the board", () => {
  const state = { playerIds: ["a", "b", "c", "d"], handCards: {}, board: {} };
  const result = deal({ ...state, phase: "dealingFasha", dealerIndex: 0 }, standardDeck(), "a", { initial: true });
  assert.equal(result.state.board.length, 4);
  assert.deepEqual(Object.values(result.state.handCards).map((hand) => hand.length), [4, 4, 4, 4]);
  assert.equal(result.deck.length, 32);
});

test("play rejects a card outside the authenticated player's hand", () => {
  const state = {
    phase: "playing", playerIds: ["a", "b", "c", "d"], currentTurnIndex: 0,
    handCards: { a: [{ suit: "hearts", rank: "ace" }] }, board: [],
  };
  assert.throws(() => playCard(state, "a", { suit: "clubs", rank: "ace" }), /not in your hand/);
});

test("cut preserves every card", () => {
  const deck = standardDeck();
  assert.deepEqual(new Set(cutDeck(deck, 17).map((card) => `${card.suit}_${card.rank}`)),
    new Set(deck.map((card) => `${card.suit}_${card.rank}`)));
});

test("only the designated cutter can transition a pre-round match", () => {
  const state = { phase: "preRoundCut", dealerIndex: 1, playerIds: ["a", "b", "c", "d"] };
  assert.throws(() => cut(state, standardDeck(), "b", 10), /Only the cutter/);
  const result = cut(state, standardDeck(), "a", 10);
  // Dealer 1 makes player 0 the cutter under the client rule.
  assert.equal(result.state.phase, "dealingFasha");
  assert.equal(result.state.deckCount, 52);
});

test("deal rejects out-of-order calls and incomplete decks", () => {
  const state = { phase: "playing", dealerIndex: 0, playerIds: ["a", "b", "c", "d"], handCards: {} };
  assert.throws(() => deal(state, standardDeck(), "a", { initial: true }), /not ready/);
  assert.throws(() => deal({ ...state, phase: "dealingFasha" }, standardDeck().slice(0, 19), "a", { initial: true }), /Not enough/);
});

test("only a host can create the hidden round deck", () => {
  const state = { phase: "waitingForPlayers", dealerIndex: 0, roundCount: 0, playerIds: ["a", "b", "c", "d"] };
  assert.throws(() => startRound(state, "b", () => 0), /room host/);
  const result = startRound(state, "a", () => 0);
  assert.equal(result.state.phase, "preRoundCut");
  assert.equal(result.state.deckCount, 52);
  assert.equal(new Set(result.deck.map((card) => `${card.suit}_${card.rank}`)).size, 52);
});
