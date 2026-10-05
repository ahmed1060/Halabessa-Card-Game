import test from "node:test";
import assert from "node:assert/strict";
import { roomSummary } from "../../supabase/functions/halabessa-api/room_summary.ts";
import { joinCommandRoom } from "../../supabase/functions/halabessa-api/room_seating.ts";

const now = Date.parse("2026-10-04T10:00:00Z");
const profile = { displayName: "New", cardBackId: "default_card", avatarUrl: "" };
function room() {
  return { protocolVersion: 1, isPublic: true, phase: "playing", currentTurnIndex: 0,
    playerIds: ["a", "bot_2", "bot_3_replacement_7", "d"],
    releasedSeats: { bot_3_replacement_7: { previousUid: "c", reason: "left" } },
    handCards: { bot_3_replacement_7: [{ suit: "hearts", rank: "ace" }] } };
}
test("released seat availability matches join policy; initial bots are occupied", () => {
  const s = room(); const summary = roomSummary(s);
  assert.equal(summary.replacementSeatCount, 1);
  assert.equal(summary.safeReplacementSeatCount, 1);
  assert.equal(summary.openSeatCount, 1);
  const joined = joinCommandRoom(s, "new", profile, now);
  assert.equal(joined.seatIndex, 2);
  assert.equal(roomSummary(joined.state).replacementSeatCount, 0);
  assert.equal(roomSummary(joined.state).safeReplacementSeatCount, 0);
});
test("active replacement turn retains listing but exposes no safe claim", () => {
  const s = { ...room(), currentTurnIndex: 2 };
  assert.equal(roomSummary(s).replacementSeatCount, 1);
  assert.equal(roomSummary(s).safeReplacementSeatCount, 0);
  assert.throws(() => joinCommandRoom(s, "new", profile, now), /no_safe_replacement_seat/);
});

test("unattended public room advertises its released active seat for recovery", () => {
  const s = { ...room(), playerIds: ["bot_1", "bot_2", "bot_3_replacement_7", "bot_4"], currentTurnIndex: 2 };
  assert.equal(roomSummary(s).safeReplacementSeatCount, 1);
  const joined = joinCommandRoom(s, "new", profile, now);
  assert.equal(joined.seatIndex, 2);
  assert.equal(roomSummary(joined.state).safeReplacementSeatCount, 0);
});
test("private, legacy and non-playing rooms do not advertise replacements", () => {
  for (const changed of [{ isPublic: false }, { protocolVersion: 0 },
    { protocolVersion: 2 }, { phase: "capturing" }, { phase: "matchOver" }]) {
    assert.equal(roomSummary({ ...room(), ...changed }).replacementSeatCount, 0);
  }
});
test("index contains no private hand or original released human identity", () => {
  const serialized = JSON.stringify(roomSummary(room()));
  assert.equal(serialized.includes('previousUid'), false);
  assert.equal(serialized.includes('handCards'), false);
  assert.equal(serialized.includes('hearts'), false);
});
test("waiting index counts empty placeholders, not bots", () => {
  const summary = roomSummary({ phase: "waitingForPlayers",
    playerIds: ["a", "bot_2", "waiting_2", "waiting_3"] });
  assert.equal(summary.openSeatCount, 2);
  assert.equal(summary.replacementSeatCount, 0);
});
test("expired active room rejects new replacement but seated reconnect remains idempotent", () => {
  const expired = { ...room(), expireAt: new Date(now - 1).toISOString() };
  assert.throws(() => joinCommandRoom(expired, "new", profile, now), /room_not_joinable/);
  assert.equal(joinCommandRoom(expired, "a", profile, now).alreadyJoined, true);
});
