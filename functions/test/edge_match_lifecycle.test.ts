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
      now += 5000;
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
  assert.equal(advanceMatch(vote.state, [], now + 20000).state.phase, "matchOver");
});
test("nonparticipants and bot identities cannot issue lifecycle commands", () => {
  assert.throws(() => lifecycleCommand("advance", room(), [], "stranger", {}, now), /human_participant_required/);
  assert.throws(() => lifecycleCommand("advance", { ...room(), playerIds: ["a", "b", "c", "bot_4"] }, [], "bot_4", {}, now), /human_participant_required/);
});
