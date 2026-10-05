import test from "node:test";
import assert from "node:assert/strict";
import { joinCommandRoom } from "../../supabase/functions/halabessa-api/room_seating.ts";
import type { MatchState } from "../../supabase/functions/halabessa-api/match_engine.ts";

const profile = { displayName: "New human", cardBackId: "default_card", avatarUrl: "" };
const now = Date.parse("2026-10-04T10:00:00Z");
function room(): MatchState {
  return { phase: "waitingForPlayers", playerIds: ["a", "waiting_1", "waiting_2", "waiting_3"],
    players: { a: true }, botInjectionVotes: { a: true }, handCards: { a: [] },
    expireAt: new Date(now + 600000).toISOString() };
}
test("versioned waiting joins fill teammate first and invalidate votes from previous occupancy", () => {
  const original = room(); const before = JSON.stringify(original);
  const second = joinCommandRoom(original, "b", profile, now);
  assert.equal(second.seatIndex, 2); assert.deepEqual(second.state.botInjectionVotes, {});
  const third = joinCommandRoom(second.state, "c", profile, now);
  const fourth = joinCommandRoom(third.state, "d", profile, now);
  assert.deepEqual(fourth.state.playerIds, ["a", "c", "b", "d"]);
  assert.equal(JSON.stringify(original), before);
  assert.throws(() => joinCommandRoom(fourth.state, "e", profile, now), /room_full/);
});
test("join retry/reconnect is a no-op for a currently seated human, including active/private rooms", () => {
  const state = { ...room(), phase: "playing", isPublic: false };
  const result = joinCommandRoom(state, "a", profile, now);
  assert.equal(result.alreadyJoined, true); assert.equal(result.state, state);
  assert.equal(result.seatIndex, 0);
});
test("expired waiting rooms and nonhuman identities cannot claim a seat", () => {
  assert.throws(() => joinCommandRoom(room(), "b", profile, now + 600000), /room_not_joinable/);
  for (const uid of ["", "bot_4", "waiting_2"]) {
    assert.throws(() => joinCommandRoom(room(), uid, profile, now), /human_seat_required/);
  }
});
test("public released seats inherit cards/team while active turn and original bots stay protected", () => {
  const state: MatchState = { phase: "playing", isPublic: true, currentTurnIndex: 1,
    playerIds: ["a", "bot_2", "bot_3_replacement_7", "d"],
    releasedSeats: { bot_3_replacement_7: { previousUid: "c", reason: "left" } },
    handCards: { bot_3_replacement_7: [{ suit: "hearts", rank: "ace" }] } };
  const result = joinCommandRoom(state, "new", profile, now);
  assert.equal(result.seatIndex, 2); assert.equal(result.state.handCards!.new.length, 1);
  assert.equal(result.state.playerIds![1], "bot_2");
  assert.throws(() => joinCommandRoom({ ...state, currentTurnIndex: 2 }, "new", profile, now), /no_safe_replacement_seat/);
  assert.throws(() => joinCommandRoom({ ...state, isPublic: false }, "new", profile, now), /no_safe_replacement_seat/);
  assert.throws(() => joinCommandRoom(result.state, "other", profile, now), /no_safe_replacement_seat/);
});

test("last-human departure can recover its active released seat with a fresh deadline", () => {
  const state: MatchState = { phase: "playing", isPublic: true, currentTurnIndex: 0,
    playerIds: ["bot_1_replacement_14", "bot_2", "bot_3", "bot_4"],
    releasedSeats: { bot_1_replacement_14: { previousUid: "a", reason: "left" } },
    turnStartTime: new Date(now - 60000).toISOString(),
    handCards: { bot_1_replacement_14: [{ suit: "hearts", rank: "ace" }] } };
  const original = JSON.stringify(state);
  const joined = joinCommandRoom(state, "a", profile, now);
  assert.equal(joined.seatIndex, 0);
  assert.equal(joined.state.handCards!.a.length, 1);
  assert.equal(joined.state.turnStartTime, new Date(now).toISOString());
  assert.equal(JSON.stringify(state), original);
  assert.throws(() => joinCommandRoom(joined.state, "other", profile, now), /no_safe_replacement_seat/);
  assert.throws(() => joinCommandRoom({ ...state, isPublic: false }, "a", profile, now), /no_safe_replacement_seat/);
  assert.throws(() => joinCommandRoom({ ...state, releasedSeats: {} }, "a", profile, now), /no_safe_replacement_seat/);
});
