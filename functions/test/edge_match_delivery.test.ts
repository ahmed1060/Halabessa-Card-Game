import test from "node:test";
import assert from "node:assert/strict";
import { commitAndDeliver, deliverLatestRoom, matchMirrorUpdates, participantSnapshot,
  type CommittedRoom } from "../../supabase/functions/halabessa-api/match_delivery.ts";

function room(version = 1): CommittedRoom {
  return { version, state: { id: "ABC12345", playerIds: ["a", "b"], phase: "playing", deckCount: 32,
    presence: { a: true }, chat: { old: { message: "hello" } }, playerLastActive: { a: "old" },
    secretDeck: [{ suit: "clubs", rank: "king" }] },
    hands: { a: [{ suit: "hearts", rank: "ace" }], b: [{ suit: "spades", rank: "two" }] } };
}

test("commit completes before any mirror; commit failure never publishes", async () => {
  const events: string[] = [];
  const delivered = await commitAndDeliver(async () => { events.push("commit"); }, async () => {
    events.push("mirror"); return room();
  });
  assert.deepEqual(events, ["commit", "mirror"]);
  assert.equal(delivered.mirrorPending, false);
  await assert.rejects(commitAndDeliver(async () => { throw new Error("commit_failed"); },
    async () => { events.push("uncommitted"); return room(); }), /commit_failed/);
  assert.equal(events.includes("uncommitted"), false);
});

test("failed delivery retains the accepted move; repair does not apply it again", async () => {
  let plays = 0;
  let committed: CommittedRoom | undefined;
  const result = await commitAndDeliver(async () => { plays++; committed = room(2); },
    async () => { throw new Error("firebase_unavailable"); });
  assert.equal(result.mirrorPending, true);
  assert.equal(result.snapshot, null);
  const repaired = await deliverLatestRoom(async publish => publish(committed!), async snapshot => {
    assert.equal(snapshot.version, 2);
  });
  assert.equal(plays, 1);
  assert.equal(repaired.version, 2);
});

test("a delayed old delivery reads the latest committed room instead of rewinding it", async () => {
  let current = room(1);
  let release!: () => void;
  const delayed = new Promise<void>(resolve => { release = resolve; });
  const mirrors: number[] = [];
  const oldDelivery = deliverLatestRoom(async publish => { await delayed; return publish(current); },
    async snapshot => { mirrors.push(snapshot.version); });
  current = room(2);
  await deliverLatestRoom(async publish => publish(current), async snapshot => { mirrors.push(snapshot.version); });
  release();
  const latest = await oldDelivery;
  assert.deepEqual(mirrors, [2, 2]);
  assert.equal(latest.version, 2);
});

test("room lock covers publication and releases after mirror errors", async () => {
  let locked = false;
  async function withLock(publish: (snapshot: CommittedRoom) => Promise<CommittedRoom>) {
    locked = true;
    try { return await publish(room()); } finally { locked = false; }
  }
  await assert.rejects(deliverLatestRoom(withLock, async () => {
    assert.equal(locked, true); throw new Error("mirror_failed");
  }), /mirror_failed/);
  assert.equal(locked, false);
});

test("public snapshots exclude secrets and participant responses contain only their own hand", () => {
  const snapshot = participantSnapshot(room(), "a");
  assert.deepEqual(snapshot.hand, room().hands.a);
  assert.deepEqual(snapshot.state.handCounts, { a: 1, b: 1 });
  for (const key of ["handCards", "deck", "secretDeck", "presence", "chat", "playerLastActive"]) {
    assert.equal(key in snapshot.state, false);
  }
  assert.deepEqual(participantSnapshot(room(), "released").hand, []);
  assert.equal(snapshot.state.deckCount, 32);
});

test("atomic mirror field updates never replace chat, presence, actions or heartbeats", () => {
  const updates = matchMirrorUpdates("ABC12345", room(), state => ({ phase: state.phase }));
  assert.equal(updates["matches/ABC12345"], undefined);
  for (const field of ["presence", "chat", "actions", "playerLastActive"]) {
    assert.equal(`matches/ABC12345/${field}` in updates, false);
  }
  assert.equal(updates["matches/ABC12345/serverVersion"], 1);
  assert.equal(updates["matches/ABC12345/handCards"], null);
  assert.equal(updates["matchSecrets/ABC12345"], null);
  assert.deepEqual(updates["matchHands/ABC12345"], room().hands);
  assert.deepEqual(updates["rooms/ABC12345"], { phase: "playing" });
  assert.throws(() => matchMirrorUpdates("bad/path", room(), () => ({})), /invalid_room_id/);
  assert.throws(() => matchMirrorUpdates("ABC12345", { ...room(), state: { "presence/other": true } }, () => ({})), /invalid_state_field/);
});

test('private realtime views pair one revision with only that human hand', () => {
  const source = room(7);
  source.state.playerIds = ['a', 'b', 'bot_1', 'waiting_3'];
  source.hands.bot_1 = [{suit: 'clubs', rank: 'king'}];
  source.hands.departed = [{suit: 'diamonds', rank: 'queen'}];
  const updates = matchMirrorUpdates('ABC12345', source, () => ({}));
  const views = updates['matchViews/ABC12345'] as Record<string, any>;
  assert.deepEqual(Object.keys(views), ['a', 'b']);
  for (const uid of ['a', 'b']) {
    assert.equal(views[uid].recipientUid, uid);
    assert.equal(views[uid].version, 7);
    assert.equal(views[uid].state.serverVersion, 7);
    assert.deepEqual(views[uid].hand, source.hands[uid]);
    assert.equal('handCards' in views[uid].state, false);
    assert.equal('deck' in views[uid].state, false);
    assert.equal('secretDeck' in views[uid].state, false);
  }
  source.state.playerIds = ['bad/path'];
  assert.throws(() => matchMirrorUpdates('ABC12345', source, () => ({})), /invalid_player_uid/);
});
