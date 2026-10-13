import test from "node:test";
import assert from "node:assert/strict";
import { advanceMatch, lifecycleCommand } from "../../supabase/functions/halabessa-api/match_lifecycle.ts";
import type { Card, MatchState } from "../../supabase/functions/halabessa-api/match_engine.ts";

let now = Date.parse("2026-10-04T10:00:00Z");
function room(): MatchState {
  return { id: "ABC12345", phase: "waitingForPlayers", playerIds: ["a", "b", "c", "d"],
    mode: "classic", maxPoints: 1, timerDurationSeconds: 15, teamAScore: 0, teamBScore: 0 };
}
test("complete server round conserves all 52 cards and reaches visible results", () => {
  let { state, deck } = advanceMatch(room(), [], now);
  assert.equal(state.phase, "preRoundCut");
  ({ state, deck } = lifecycleCommand("cut", state, deck, "d", { position: 20 }, now));
  assert.throws(() => advanceMatch(state, deck, now + 3999), /no_transition_due/);
  now += 4000;
  ({ state, deck } = advanceMatch(state, deck, now));
  assert.equal(state.phase, "dealingCards");
  assert.throws(() => advanceMatch(state, deck, now + 4999), /no_transition_due/);
  now += 5000;
  ({ state, deck } = advanceMatch(state, deck, now));
  let plays = 0;
  for (let step = 0; step < 150 && state.phase !== "rematchVoting"; step++) {
    if (state.phase === "playing" && state.playerIds!.some(uid => state.handCards?.[uid]?.length)) {
      const uid = state.playerIds![Number(state.currentTurnIndex)];
      const hand = state.handCards![uid];
      const card = hand.find(c => c.rank === state.board?.at(-1)?.rank) ?? hand[0];
      ({ state, deck } = lifecycleCommand("playCard", state, deck, uid, { card }, now));
      plays++;
    } else {
      now += state.phase === 'roundScoring' ? 8000 : 5000;
      ({ state, deck } = advanceMatch(state, deck, now));
    }
    if (state.phase !== "capturing") {
      const harvest = Object.values(state.harvestStacks as Record<string, { leadingCard: Card; capturedCards: Card[] }[]> ?? {})
        .flatMap(captures => captures.flatMap(capture => [...capture.capturedCards, capture.leadingCard]));
      const cards = [...deck, ...(state.board ?? []), ...Object.values(state.handCards ?? {}).flat(), ...harvest];
      assert.equal(cards.length, 52);
      assert.equal(new Set(cards.map(c => `${c.suit}_${c.rank}`)).size, 52);
    }
  }
  assert.equal(plays, 48);
  assert.equal((state.playHistory as Card[]).length, 48);
  assert.equal(state.phase, "rematchVoting");
  assert.equal(state.settlementPending, true);
  assert.equal(Object.keys(state.earnedCoins as Record<string, number>).length, 4);
});
test("server phase delays and bot turns can be advanced by any human, not only the host", () => {
  const initial = { ...room(), playerIds: ["a", "b", "c", "bot_4"] };
  const round = lifecycleCommand("advance", initial, [], "b", {}, now);
  assert.equal(round.state.phase, "preRoundCut");
  assert.throws(() => lifecycleCommand("advance", round.state, round.deck, "b", {}, now + 999), /no_transition_due/);
  const cut = lifecycleCommand("advance", round.state, round.deck, "b", {}, now + 1000);
  assert.equal(cut.state.phase, "dealingFasha");
});
test("unfilled rooms do not start; bot injection requires each present human's vote", () => {
  const initial = { ...room(), playerIds: ["a", "waiting_1", "c", "waiting_3"] };
  assert.throws(() => advanceMatch(initial, [], now), /no_transition_due/);
  const a = lifecycleCommand("voteForBots", initial, [], "a", {}, now);
  assert.equal(a.state.playerIds![1], "waiting_1");
  const c = lifecycleCommand("voteForBots", a.state, [], "c", {}, now);
  assert.equal(c.state.playerIds![1], "bot_2");
  assert.equal(c.state.playerIds![3], "bot_4");
  assert.equal(advanceMatch(c.state, [], now).state.phase, "preRoundCut");
});
test("rematch expires rather than waiting forever; duplicate or invalid votes are rejected", () => {
  const initial = { ...room(), phase: "rematchVoting", phaseStartedAt: new Date(now).toISOString() };
  const vote = lifecycleCommand("voteRematch", initial, [], "a", { vote: true }, now);
  assert.throws(() => lifecycleCommand("voteRematch", vote.state, [], "a", { vote: true }, now), /already_voted/);
  assert.throws(() => lifecycleCommand("voteRematch", initial, [], "a", { vote: "yes" }, now), /invalid_vote/);
  assert.throws(() => advanceMatch(vote.state, [], now + 9999), /no_transition_due/);
  const expired = advanceMatch(vote.state, [], now + 10000).state;
  assert.equal(expired.phase, "matchOver");
  assert.deepEqual(expired.rematchVotes, { a: true, b: false, c: false, d: false });
  assert.throws(() => lifecycleCommand('voteRematch', initial, [], 'b', {vote: true}, now + 10000), /vote_deadline_reached/);
});
test("nonparticipants and bot identities cannot issue lifecycle commands", () => {
  assert.throws(() => lifecycleCommand("advance", room(), [], "stranger", {}, now), /human_participant_required/);
  assert.throws(() => lifecycleCommand("advance", { ...room(), playerIds: ["a", "b", "c", "bot_4"] }, [], "bot_4", {}, now), /human_participant_required/);
});

test("unlimited gameplay still has a bounded cut phase", () => {
  const round = advanceMatch({ ...room(), timerDurationSeconds: 0 }, [], now);
  assert.throws(() => advanceMatch(round.state, round.deck, now + 14999), /no_transition_due/);
  assert.equal(advanceMatch(round.state, round.deck, now + 15000).state.phase, "dealingFasha");
});

test("capture animation has one harvest record and grants the next turn a fresh deadline", () => {
  const state: MatchState = { ...room(), phase: "playing", currentTurnIndex: 0,
    turnStartTime: new Date(now).toISOString(), handCards: {
      a: [{ suit: "hearts", rank: "ace" }], b: [], c: [], d: [] },
    board: [{ suit: "diamonds", rank: "ace" }] };
  const captured = lifecycleCommand("playCard", state, [], "a", { card: state.handCards!.a[0] }, now);
  const harvest = JSON.stringify(captured.state.harvestStacks);
  assert.equal(captured.state.phase, "capturing");
  assert.deepEqual(captured.state.playHistory, [state.handCards!.a[0]]);
  assert.throws(() => lifecycleCommand("playCard", captured.state, [], "b", { card: state.handCards!.a[0] }, now + 1), /play_not_ready/);
  assert.throws(() => advanceMatch(captured.state, [], now + 1399), /no_transition_due/);
  const finished = advanceMatch(captured.state, [], now + 1400);
  assert.equal(finished.state.phase, "playing");
  assert.deepEqual(finished.state.board, []);
  assert.equal(JSON.stringify(finished.state.harvestStacks), harvest);
  assert.equal(finished.state.turnStartTime, new Date(now + 1400).toISOString());
});

test("unanimous rematch cannot discard pending rewards; settled rematch resets scores", () => {
  const state = { ...room(), phase: "rematchVoting", phaseStartedAt: new Date(now).toISOString(),
    teamAScore: 41, teamBScore: 20, settlementPending: true,
    rematchVotes: { a: true, b: true, c: true, d: true } };
  assert.throws(() => advanceMatch(state, [], now + 1000), /settlement_pending/);
  const restarted = advanceMatch({ ...state, settlementPending: false }, [], now + 1000);
  assert.equal(restarted.state.teamAScore, 0);
  assert.equal(restarted.state.teamBScore, 0);
  assert.equal(restarted.state.roundCount, 1);
  assert.equal(restarted.state.matchSequence, 1);
  assert.equal(restarted.deck.length, 52);
  assert.deepEqual(restarted.state.earnedCoins, {});
});

function oneCardRoom(): MatchState {
  return { ...room(), phase: 'playing', currentTurnIndex: 0,
    turnStartTime: new Date(now).toISOString(), consecutiveTimeouts: {a: 2},
    handCards: {a: [{suit: 'hearts', rank: 'ace'}],
      b: [{suit: 'clubs', rank: 'two'}, {suit: 'clubs', rank: 'three'}],
      c: [{suit: 'spades', rank: 'four'}], d: [{suit: 'diamonds', rank: 'five'}]},
    board: [], harvestStacks: {teamA: [], teamB: []} };
}

test('a forced last card uses server time, preserves inactivity and plays exactly once', () => {
  const initial = oneCardRoom();
  assert.throws(() => lifecycleCommand('advance', initial, [], 'b', {}, now + 899), /turn_deadline_not_reached/);
  const next = lifecycleCommand('advance', initial, [], 'b', {}, now + 900).state;
  assert.equal(next.currentTurnIndex, 1);
  assert.deepEqual(next.handCards!.a, []);
  assert.deepEqual(next.board, initial.handCards!.a);
  assert.equal((next.playHistory as Card[]).length, 1);
  assert.deepEqual(next.consecutiveTimeouts, {a: 2});
  assert.equal(next.playerIds![0], 'a');
  assert.equal(next.turnStartTime, new Date(now + 900).toISOString());
  assert.throws(() => lifecycleCommand('advance', next, [], 'b', {}, now + 901), /turn_deadline_not_reached/);
  assert.throws(() => lifecycleCommand('playCard', next, [], 'a', {card: initial.handCards!.a[0]}, now + 901), /not_your_turn/);
});

test('forced last-card play works without a turn timer and cannot affect a non-active hand', () => {
  const initial = {...oneCardRoom(), timerDurationSeconds: 0};
  assert.equal(advanceMatch(initial, [], now + 900).state.handCards!.a.length, 0);
  assert.throws(() => advanceMatch({...initial, currentTurnIndex: 1}, [], now + 900), /turn_deadline_not_reached/);
  assert.throws(() => advanceMatch({...initial, turnStartTime: new Date(now + 1000).toISOString()}, [], now + 900), /turn_deadline_not_reached/);
  assert.throws(() => lifecycleCommand('advance', initial, [], 'stranger', {}, now + 900), /human_participant_required/);
});

test('last-card capture has a single harvest entry and one completion transition', () => {
  const initial = {...oneCardRoom(), mode: 'tafweet', board: [{suit: 'diamonds', rank: 'ace'} as Card]};
  const captured = advanceMatch(initial, [], now + 900).state;
  assert.equal(captured.phase, 'capturing');
  assert.equal(captured.capturingStage, 0);
  assert.equal(captured.handCards!.a.length, 0);
  const harvest = JSON.stringify(captured.harvestStacks);
  assert.throws(() => advanceMatch(captured, [], now + 2299), /no_transition_due/);
  const finished = advanceMatch(captured, [], now + 2300).state;
  assert.equal(finished.phase, 'playing');
  assert.deepEqual(finished.board, []);
  assert.equal(JSON.stringify(finished.harvestStacks), harvest);
  assert.equal((finished.playHistory as Card[]).length, 1);
});

test('manual play winning the race cancels the forced move; bots use the same single-card policy', () => {
  const initial = oneCardRoom();
  const manual = lifecycleCommand('playCard', initial, [], 'a', {card: initial.handCards!.a[0]}, now + 899).state;
  assert.throws(() => advanceMatch(manual, [], now + 900), /turn_deadline_not_reached/);
  const bot = {...initial, playerIds: ['bot_1', 'b', 'c', 'd'], handCards: {...initial.handCards, bot_1: initial.handCards!.a}};
  assert.throws(() => advanceMatch(bot, [], now + 899), /no_transition_due/);
  assert.equal(advanceMatch(bot, [], now + 900).state.handCards!.bot_1.length, 0);
});

test('a complete round with twelve forced last cards neither skips a deal nor loses cards', () => {
  let clock = Date.parse('2026-10-11T12:00:00Z');
  let {state, deck} = advanceMatch(room(), [], clock);
  ({state, deck} = lifecycleCommand('cut', state, deck, 'd', {position: 20}, clock));
  let forced = 0, manual = 0;
  for (let step = 0; step < 160 && state.phase !== 'rematchVoting'; step++) {
    if (state.phase === 'playing' && state.playerIds!.some(uid => state.handCards?.[uid]?.length)) {
      const uid = state.playerIds![Number(state.currentTurnIndex)];
      const hand = state.handCards![uid];
      if (hand.length === 1) {
        clock += 900;
        ({state, deck} = advanceMatch(state, deck, clock));
        forced++;
      } else {
        const card = hand.find(c => c.rank === state.board?.at(-1)?.rank) ?? hand[0];
        ({state, deck} = lifecycleCommand('playCard', state, deck, uid, {card}, clock));
        manual++;
      }
    } else {
      clock += state.phase === 'capturing' ? 1400 : state.phase === 'roundScoring' ? 8000 : 5000;
      ({state, deck} = advanceMatch(state, deck, clock));
    }
    if (state.phase !== 'capturing') {
      const harvest = Object.values(state.harvestStacks as Record<string, {leadingCard: Card; capturedCards: Card[]}[]> ?? {})
        .flatMap(captures => captures.flatMap(capture => [...capture.capturedCards, capture.leadingCard]));
      const cards = [...deck, ...(state.board ?? []), ...Object.values(state.handCards ?? {}).flat(), ...harvest];
      assert.equal(cards.length, 52);
      assert.equal(new Set(cards.map(c => c.suit + '_' + c.rank)).size, 52);
    }
  }
  assert.equal(forced, 12);
  assert.equal(manual, 36);
  assert.equal((state.playHistory as Card[]).length, 48);
  assert.equal(state.handInRound, 3);
  assert.equal(state.phase, 'rematchVoting');
});
