import test from "node:test";
import assert from "node:assert/strict";
import { executeMatchIntent } from "../../supabase/functions/halabessa-api/match_commands.ts";
import type { MatchState } from "../../supabase/functions/halabessa-api/match_engine.ts";

const now = Date.parse("2026-10-04T10:00:00Z");
function room(): MatchState {
  return { id: "ABC12345", phase: "waitingForPlayers", playerIds: ["a", "b", "c", "d"],
    mode: "classic", timerDurationSeconds: 15, maxPoints: 41, teamAScore: 0, teamBScore: 0 };
}
function playing(): MatchState {
  return { ...room(), phase: "playing", currentTurnIndex: 0, turnStartTime: new Date(now).toISOString(),
    handCards: { a: [{ suit: "hearts", rank: "ace" }, { suit: "clubs", rank: "two" }],
      b: [{ suit: "clubs", rank: "three" }], c: [], d: [] }, board: [], consecutiveTimeouts: { a: 2 } };
}
test("authenticated caller cannot proxy another human or bot, even for phase commands", () => {
  for (const type of ["advance", "startRound", "playCard", "leave", "cut", "dealInitial"]) {
    for (const actor of ["b", "bot_2"]) {
      assert.throws(() => executeMatchIntent(type, room(), [], "a", actor, {}, now), /invalid_command_actor/);
    }
  }
});
test("nonhost human can advance preparation; outsiders and bot identities cannot", () => {
  assert.equal(executeMatchIntent("startRound", room(), [], "b", "b", {}, now).state.phase, "preRoundCut");
  assert.throws(() => executeMatchIntent("advance", room(), [], "outsider", "outsider", {}, now), /human_participant_required/);
  assert.throws(() => executeMatchIntent("advance", { ...room(), playerIds: ["a", "b", "c", "bot_4"] }, [],
    "bot_4", "bot_4", {}, now), /human_participant_required/);
});
test("compatibility phase commands cannot skip server animation delays or restart an active match", () => {
  const round = executeMatchIntent("startRound", room(), [], "a", "a", {}, now);
  const cut = executeMatchIntent("cut", round.state, round.deck, "d", "d", { position: 20 }, now);
  const dealt = executeMatchIntent("dealInitial", cut.state, cut.deck, "b", "b", {}, now);
  assert.throws(() => executeMatchIntent("beginPlay", dealt.state, dealt.deck, "a", "a", {}, now + 4999), /no_transition_due/);
  const ready = executeMatchIntent("beginPlay", dealt.state, dealt.deck, "b", "b", {}, now + 5000);
  assert.equal(ready.state.phase, "playing");
  assert.throws(() => executeMatchIntent("startRound", ready.state, ready.deck, "a", "a", {}, now), /phase_not_ready/);
  assert.throws(() => executeMatchIntent("dealSubsequent", ready.state, ready.deck, "a", "a", {}, now), /hands_not_empty/);
});
test("manual cut at its deadline is rejected; server automatic cut advances once", () => {
  const round = executeMatchIntent("advance", room(), [], "b", "b", {}, now);
  assert.throws(() => executeMatchIntent("cut", round.state, round.deck, "d", "d", { position: 20 }, now + 15000), /cut_deadline_reached/);
  const cut = executeMatchIntent("advance", round.state, round.deck, "b", "b", {}, now + 15000);
  assert.equal(cut.state.phase, "dealingFasha");
  assert.throws(() => executeMatchIntent("cut", cut.state, cut.deck, "d", "d", { position: 20 }, now + 15001), /cut_not_ready/);
});
test("advance before deadline cannot play for an offline human or trust a client timeout flag", () => {
  const state = { ...playing(), playerOnlineStatus: { a: false } };
  const before = JSON.stringify(state);
  assert.throws(() => executeMatchIntent("advance", state, [], "b", "b", { timeout: true, now: now + 999999 }, now + 14999), /turn_deadline_not_reached/);
  assert.equal(JSON.stringify(state), before);
});
test("third accepted timeout plays one card then releases only the inactive seat", () => {
  const state = playing();
  const after = executeMatchIntent("advance", state, [], "b", "b", {}, now + 15000).state;
  const bot = after.playerIds![0];
  assert.match(bot, /^bot_/);
  assert.equal(after.currentTurnIndex, 1);
  assert.equal(after.handCards![bot].length, 1);
  assert.equal(after.board!.length, 1);
  assert.equal(after.playerIds![2], "c");
  assert.equal(state.handCards!.a.length, 2);
  assert.throws(() => executeMatchIntent("advance", after, [], "b", "b", {}, now + 15000), /turn_deadline_not_reached/);
});
test("accepted manual play resets timeout count and cannot be repeated after turn changes", () => {
  const state = playing();
  const after = executeMatchIntent("playCard", state, [], "a", "a", { card: state.handCards!.a[0] }, now + 14999).state;
  assert.equal((after.consecutiveTimeouts as Record<string, number>).a, 0);
  assert.throws(() => executeMatchIntent("playCard", after, [], "a", "a", { card: state.handCards!.a[1] }, now + 14999), /not_your_turn/);
});
test("explicit leave is caller-owned and preserves remaining hand and teammate", () => {
  const state = playing();
  const after = executeMatchIntent("leave", state, [], "a", "a", {}, now).state;
  assert.equal(after.handCards![after.playerIds![0]].length, 2);
  assert.equal(after.playerIds![2], "c");
  assert.equal(after.currentTurnIndex, 0);
  assert.throws(() => executeMatchIntent("leave", after, [], "a", "a", {}, now), /human_participant_required/);
});
test("voting commands are available through the same verified caller dispatcher", () => {
  const waiting = { ...room(), playerIds: ["a", "waiting_1", "waiting_2", "waiting_3"] };
  const filled = executeMatchIntent("voteForBots", waiting, [], "a", "a", {}, now).state;
  assert.deepEqual(filled.playerIds, ["a", "bot_2", "bot_3", "bot_4"]);
  const vote = executeMatchIntent("voteRematch", { ...room(), phase: "rematchVoting" }, [], "b", "b", { vote: false }, now).state;
  assert.equal((vote.rematchVotes as Record<string, boolean>).b, false);
});
