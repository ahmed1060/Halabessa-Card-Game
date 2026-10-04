import test from "node:test";
import assert from "node:assert/strict";
import { claimReplacement, manualPlay, releasePlayer, replacementSeatIndex, timeoutPlay } from "../../supabase/functions/halabessa-api/turn_policy.ts";
import type { MatchState } from "../../supabase/functions/halabessa-api/match_engine.ts";

const now = Date.parse("2026-10-04T10:00:15Z");
function match(): MatchState {
  return { id: "ABC12345", phase: "playing", isPublic: true,
    playerIds: ["a", "b", "c", "d"], currentTurnIndex: 0, serverVersion: 1,
    turnStartTime: "2026-10-04T10:00:00Z", timerDurationSeconds: 15,
    players: { a: true, b: true, c: true, d: true },
    playerOnlineStatus: { a: false, b: true },
    handCards: { a: [{ suit: "hearts", rank: "ace" }, { suit: "clubs", rank: "two" }], b: [], c: [], d: [] },
    board: [], consecutiveTimeouts: {} };
}
test("offline status does not authorize an early timeout move", () => {
  assert.throws(() => timeoutPlay(match(), now - 1), /turn_deadline_not_reached/);
  assert.throws(() => timeoutPlay({ ...match(), turnStartTime: null }, now), /turn_deadline_not_reached/);
});
test("accepted timeouts play exactly one card; first two retain the human", () => {
  for (const prior of [0, 1]) {
    const before = { ...match(), consecutiveTimeouts: { a: prior } };
    const after = timeoutPlay(before, now);
    assert.equal(after.playerIds?.[0], "a");
    assert.equal(after.handCards?.a.length, 1);
    assert.equal(after.board?.length, 1);
    assert.equal((after.consecutiveTimeouts as Record<string, number>).a, prior + 1);
    assert.equal(before.handCards?.a.length, 2);
    assert.throws(() => timeoutPlay(after, now), /turn_deadline_not_reached/);
  }
});
test("third accepted timeout releases the seat to a bot without losing cards or team", () => {
  const after = timeoutPlay({ ...match(), consecutiveTimeouts: { a: 2 } }, now);
  const bot = after.playerIds![0];
  assert.match(bot, /^bot_/);
  assert.equal(after.playerIds?.[2], "c");
  assert.equal(after.currentTurnIndex, 1);
  assert.equal(after.handCards?.[bot].length, 1);
  assert.equal(after.handCards?.a, undefined);
  assert.equal(after.board?.length, 1);
  assert.equal((after.players as Record<string, boolean>).a, undefined);
});
test("valid manual move resets streak, rejected move does not", () => {
  const before = { ...match(), consecutiveTimeouts: { a: 2 } };
  assert.throws(() => manualPlay(before, "a", { suit: "spades", rank: "king" }, now - 1), /card_not_owned/);
  assert.equal(before.consecutiveTimeouts.a, 2);
  const after = manualPlay(before, "a", before.handCards!.a[0], now - 1);
  assert.equal((after.consecutiveTimeouts as Record<string, number>).a, 0);
});
test("capture policy preserves the previous ownership, skips and harvest snapshot", () => {
  const before = { ...match(), board: [{ suit: "diamonds", rank: "ace" }],
    cardOwnership: { diamonds_ace: "d" }, skippedMatches: {}, harvestStacks: { teamA: [], teamB: [] } };
  const json = JSON.stringify(before);
  manualPlay(before, "a", before.handCards!.a[0], now - 1);
  assert.equal(JSON.stringify(before), json);
});

test("deadline boundary reserves the turn for exactly one timeout; unlimited turns stay manual", () => {
  const before = match();
  assert.throws(() => manualPlay(before, "a", before.handCards!.a[0], now), /turn_deadline_reached/);
  assert.equal(timeoutPlay(before, now).handCards?.a.length, 1);
  assert.equal(manualPlay({ ...before, timerDurationSeconds: 0 }, "a", before.handCards!.a[0], now + 99999).handCards?.a.length, 1);
  assert.throws(() => timeoutPlay({ ...before, timerDurationSeconds: 0 }, now + 99999), /turn_deadline_not_reached/);
});

test("leaving a waiting room reopens a human seat rather than adding an unvoted bot", () => {
  const after = releasePlayer({ ...match(), phase: "waitingForPlayers", handCards: {} }, "a", "left");
  assert.equal(after.playerIds![0], "waiting_0");
  assert.equal((after.players as Record<string, boolean>).waiting_0, undefined);
  assert.deepEqual(after.releasedSeats, {});
});

test("replacement inherits cards and team, keeps Tafweet references, and cannot claim twice", () => {
  const before = { ...match(), cardOwnership: { hearts_ace: "a" }, skippedMatches: { b: ["ace:a"] } };
  const released = releasePlayer(before, "a", "left");
  assert.throws(() => claimReplacement(released, "new", { displayName: "New", cardBackId: "default", avatarUrl: "" }), /no_safe_replacement_seat/);
  const ready = { ...released, currentTurnIndex: 1 };
  const json = JSON.stringify(ready);
  const after = claimReplacement(ready, "new", { displayName: "New", cardBackId: "default", avatarUrl: "" });
  assert.equal(after.playerIds![0], "new");
  assert.equal(after.playerIds![2], "c");
  assert.equal(after.handCards!.new.length, 2);
  assert.equal((after.cardOwnership as Record<string, string>).hearts_ace, "new");
  assert.deepEqual((after.skippedMatches as Record<string, string[]>).b, ["ace:new"]);
  assert.equal(JSON.stringify(ready), json);
  assert.equal(replacementSeatIndex(after), -1);
  assert.throws(() => claimReplacement(after, "other", { displayName: "Other", cardBackId: "default", avatarUrl: "" }), /no_safe_replacement_seat/);
});
test("explicit leave preserves all remaining cards and marks a safe replacement vacancy", () => {
  const before = match();
  const after = releasePlayer(before, "a", "left");
  const bot = after.playerIds![0];
  assert.equal(after.handCards?.[bot].length, 2);
  assert.equal(replacementSeatIndex(after), -1); // active controller cannot change mid-turn
  assert.equal(replacementSeatIndex({ ...after, currentTurnIndex: 1 }), 0);
  assert.equal(replacementSeatIndex({ ...after, currentTurnIndex: 1, isPublic: false }), -1);
  assert.equal(replacementSeatIndex({ ...before, playerIds: ["bot_1", "b", "c", "d"] }), -1);
  assert.equal(before.playerIds?.[0], "a");
});
