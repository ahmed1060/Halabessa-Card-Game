import assert from "node:assert/strict";
import test from "node:test";

import {
  cut,
  deal,
  playCard,
  startRound,
  type Card,
  type MatchState,
} from "../../supabase/functions/halabessa-api/match_engine.ts";

const players = ["player-one", "player-two", "player-three", "player-four"];

function waitingState(): MatchState {
  return {
    id: "ABC12345",
    phase: "waitingForPlayers",
    playerIds: players,
    dealerIndex: 0,
    currentTurnIndex: 1,
    roundCount: 0,
  };
}

test("starts a round with one complete unique hidden deck", () => {
  const result = startRound(waitingState(), players[0]);
  const keys = result.deck.map((card) => `${card.suit}_${card.rank}`);

  assert.equal(result.state.phase, "preRoundCut");
  assert.equal(result.state.deckCount, 52);
  assert.equal(result.deck.length, 52);
  assert.equal(new Set(keys).size, 52);
  assert.deepEqual(result.state.handCards, {});
});

test("rejects round creation by a non-host participant", () => {
  assert.throws(() => startRound(waitingState(), players[1]), /host_required/);
});

test("only the player before the dealer can cut", () => {
  const started = startRound(waitingState(), players[0]);

  assert.throws(() => cut(started.state, started.deck, players[1], 20), /cutter_required/);
  const result = cut(started.state, started.deck, players[3], 20);
  assert.equal(result.state.phase, "dealingFasha");
  assert.equal(result.deck.length, 52);
  assert.deepEqual(result.deck.slice(0, 32), started.deck.slice(20));
});

test("initial deal creates four private hands and four board cards", () => {
  const started = startRound(waitingState(), players[0]);
  const cutResult = cut(started.state, started.deck, players[3], 20);
  const result = deal(cutResult.state, cutResult.deck, players[0], true);

  assert.equal(result.state.phase, "dealingCards");
  assert.equal((result.state.board as Card[]).length, 4);
  assert.equal(result.deck.length, 32);
  for (const player of players) {
    assert.equal(result.state.handCards?.[player].length, 4);
  }
});

test("play enforces both the current turn and private hand ownership", () => {
  const ownedCard = { suit: "hearts", rank: "ace" };
  const state: MatchState = {
    phase: "playing",
    playerIds: players,
    currentTurnIndex: 1,
    board: [],
    handCards: { [players[1]]: [ownedCard] },
  };

  assert.throws(() => playCard(state, players[0], ownedCard), /not_your_turn/);
  assert.throws(
    () => playCard(state, players[1], { suit: "spades", rank: "king" }),
    /card_not_owned/,
  );
  const result = playCard(state, players[1], ownedCard);
  assert.equal(result.currentTurnIndex, 2);
  assert.equal(result.handCards?.[players[1]].length, 0);
  assert.deepEqual(result.board, [ownedCard]);
});

test("matching the top rank sweeps the board into the actor's team harvest", () => {
  const played = { suit: "spades", rank: "seven" };
  const board = [
    { suit: "clubs", rank: "two" },
    { suit: "diamonds", rank: "seven" },
  ];
  const state: MatchState = {
    mode: "classic",
    phase: "playing",
    playerIds: players,
    currentTurnIndex: 2,
    board,
    handCards: { [players[2]]: [played] },
    harvestStacks: { teamA: [], teamB: [] },
    teamAScore: 0,
    teamBScore: 0,
  };

  const result = playCard(state, players[2], played);
  const captures = result.harvestStacks as Record<string, unknown[]>;
  assert.deepEqual(result.board, []);
  assert.equal(captures.teamA.length, 1);
  assert.equal(result.teamAScore, 1);
  assert.equal(result.lastCaptureTeam, "teamA");
});

test("subsequent deal requires every hand to be empty", () => {
  const deck = startRound(waitingState(), players[0]).deck;
  const state: MatchState = {
    phase: "playing",
    playerIds: players,
    dealerIndex: 0,
    handCards: { [players[1]]: [{ suit: "clubs", rank: "two" }] },
  };

  assert.throws(() => deal(state, deck, players[0], false), /cards_remain_in_hands/);
});
