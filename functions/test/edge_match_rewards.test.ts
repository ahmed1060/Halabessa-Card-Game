import test from "node:test";
import assert from "node:assert/strict";
import { rewardPlan, rewardWrites, settleRewardPlan, type ProfileDocument, type RewardPlan } from "../../supabase/functions/halabessa-api/match_rewards.ts";
import { createFirestoreRewardStore } from "../../supabase/functions/halabessa-api/firestore_rewards.ts";
import type { MatchState } from "../../supabase/functions/halabessa-api/match_engine.ts";
import { releasePlayer } from "../../supabase/functions/halabessa-api/turn_policy.ts";
import { advanceMatch } from "../../supabase/functions/halabessa-api/match_lifecycle.ts";

const base = "projects/test/databases/(default)/documents";
function match(): MatchState {
  return { id: "ABC12345", protocolVersion: 1, settlementPending: true, phase: "rematchVoting", maxPoints: 41,
    rewardRoster: ["a", "b", "c", "bot_4"], rewardScores: { teamA: 42, teamB: 33 }, matchSequence: 0 };
}
const created = "2026-10-04 10:00:00+00";
function profile(uid: string, points = 20): ProfileDocument {
  return { name: `${base}/users/${uid}`, updateTime: "2026-10-04T10:00:00Z",
    fields: { points: { integerValue: String(points) }, coins: { integerValue: "200" },
      owned_skins: { arrayValue: { values: [{ stringValue: "paid_skin" }] } },
      diamonds: { integerValue: "77" }, wins: { integerValue: "3" },
      bestScore: { integerValue: "99" } } };
}
test("reward plan uses server-frozen roster/scores, skips bots and ignores client award maps", async () => {
  const state = { ...match(), playerIds: ["bot_1_replacement_9", "b", "c", "bot_4"],
    earnedCoins: { a: 999999 }, earnedStars: { a: 999999 } };
  const plan = await rewardPlan(state, created);
  assert.deepEqual(plan.rewards, [
    { uid: "a", points: 50, coins: 100, won: true, teamScore: 42 },
    { uid: "b", points: -30, coins: 20, won: false, teamScore: 33 },
    { uid: "c", points: 50, coins: 100, won: true, teamScore: 42 },
  ]);
  assert.match(plan.receiptId, /^[a-f0-9]{64}$/);
});
test("legacy, unfinished, malformed, duplicate and path-like identities cannot earn rewards", async () => {
  for (const patch of [{ protocolVersion: 0 }, { settlementPending: false }, { phase: "playing" },
    { rewardScores: { teamA: 4, teamB: 3 } }, { matchSequence: -1 },
    { rewardRoster: ["a", "a", "c", "d"] }, { rewardRoster: ["a/users/b", "b", "c", "d"] }]) {
    await assert.rejects(() => rewardPlan({ ...match(), ...patch }, created));
  }
});
test("new rematches and reused room IDs have different receipts; existing winner priority is preserved", async () => {
  const original = await rewardPlan(match(), created);
  assert.notEqual((await rewardPlan({ ...match(), matchSequence: 1 }, created)).receiptId, original.receiptId);
  assert.notEqual((await rewardPlan(match(), "2026-10-05 10:00:00+00")).receiptId, original.receiptId);
  const both = await rewardPlan({ ...match(), rewardScores: { teamA: 43, teamB: 41 } }, created);
  assert.equal(both.rewards[0].won, true);
});
test("departure after results does not change the roster or receipt; pending rematch cannot discard it", async () => {
  const completed = { ...match(), playerIds: ["a", "b", "c", "bot_4"],
    phaseStartedAt: "2026-10-04T10:00:00Z", rematchVotes: { a: true, b: true, c: true },
    teamAScore: 42, teamBScore: 33 };
  const plan = await rewardPlan(completed, created);
  const left = releasePlayer(completed, "a", "left");
  assert.deepEqual(await rewardPlan(left, created), plan);
  assert.throws(() => advanceMatch(completed, [], Date.parse("2026-10-04T10:00:01Z")), /settlement_pending/);
  const next = advanceMatch({ ...completed, settlementPending: false, rewardReceiptId: plan.receiptId }, [],
    Date.parse("2026-10-04T10:00:01Z")).state;
  assert.equal(next.matchSequence, 1); assert.deepEqual(next.rewardRoster, []);
  assert.equal(next.rewardReceiptId, null); assert.equal(next.settlementPending, false);
});
test("conditional masked writes clamp stars and preserve purchases, diamonds and best score", async () => {
  const plan = await rewardPlan(match(), created);
  const profiles = [profile("a", 999990), profile("b"), profile("c")];
  const before = JSON.stringify(profiles);
  const writes = rewardWrites(base, plan, profiles) as any[];
  assert.equal(writes[0].update.fields.points.integerValue, "999999");
  assert.equal(writes[1].update.fields.points.integerValue, "0");
  assert.equal(writes[0].update.fields.coins.integerValue, "300");
  assert.equal(writes[0].update.fields.bestScore.integerValue, "99");
  assert.deepEqual(writes[0].currentDocument, { updateTime: profiles[0].updateTime });
  assert.equal(writes[0].updateMask.fieldPaths.includes("owned_skins"), false);
  assert.equal(writes[0].updateMask.fieldPaths.includes("diamonds"), false);
  assert.deepEqual(writes.at(-1).currentDocument, { exists: false });
  assert.equal(JSON.stringify(profiles), before);
});
test("missing/wrong profiles and unsafe stats abort rather than overwriting or creating wallets", async () => {
  const plan = await rewardPlan(match(), created);
  assert.throws(() => rewardWrites(base, plan, []), /reward_profile_missing/);
  assert.throws(() => rewardWrites(base, plan, [profile("other"), profile("b"), profile("c")]), /invalid_reward_profile/);
  const malformed = profile("a"); malformed.fields.coins = { stringValue: "100" };
  assert.throws(() => rewardWrites(base, plan, [malformed, profile("b"), profile("c")]), /invalid_reward_profile/);
});
function memoryStore(plan: RewardPlan, ambiguous = false) {
  let receipt: string | null = null, credits = 0;
  return { readReceipt: async () => receipt,
    readProfiles: async (uids: string[]) => uids.map(uid => profile(uid)),
    commit: async () => {
      if (receipt) throw new Error("reward_commit_conflict");
      receipt = plan.fingerprint; credits++;
      if (ambiguous) throw new Error("reward_transport_failed");
    }, get credits() { return credits; } };
}
test("lost commit response is reconciled from receipt without crediting twice", async () => {
  const plan = await rewardPlan(match(), created); const store = memoryStore(plan, true);
  assert.equal((await settleRewardPlan(base, plan, store)).duplicate, true);
  assert.equal((await settleRewardPlan(base, plan, store)).duplicate, true);
  assert.equal(store.credits, 1);
});
test("concurrent settlements credit once and an existing mismatched receipt fails closed", async () => {
  const plan = await rewardPlan(match(), created); const store = memoryStore(plan);
  const results = await Promise.all([settleRewardPlan(base, plan, store), settleRewardPlan(base, plan, store)]);
  assert.equal(results.filter(r => !r.duplicate).length, 1); assert.equal(store.credits, 1);
  await assert.rejects(() => settleRewardPlan(base, { ...plan, fingerprint: "other" }, store), /reward_receipt_conflict/);
});
test("profile conflicts re-read latest data and repeated ambiguity is bounded", async () => {
  const plan = await rewardPlan(match(), created); let reads = 0, commits = 0;
  const store = { readReceipt: async () => null,
    readProfiles: async (uids: string[]) => { reads++; return uids.map(uid => profile(uid, 20 + reads)); },
    commit: async () => { commits++; if (commits === 1) throw new Error("reward_commit_conflict"); } };
  assert.equal((await settleRewardPlan(base, plan, store)).settled, true); assert.equal(reads, 2);
  store.commit = async () => { throw new Error("reward_transport_failed"); };
  await assert.rejects(() => settleRewardPlan(base, plan, store), /reward_settlement_retry_required/);
});
test("permission failures are not retried or converted into successful settlement", async () => {
  const plan = await rewardPlan(match(), created); let commits = 0;
  await assert.rejects(() => settleRewardPlan(base, plan, { readReceipt: async () => null,
    readProfiles: async uids => uids.map(uid => profile(uid)),
    commit: async () => { commits++; throw new Error("reward_access_denied"); } }), /reward_access_denied/);
  assert.equal(commits, 1);
});
test("Firestore adapter uses atomic commit and distinguishes permission from precondition failure", async () => {
  const plan = await rewardPlan(match(), created); const paths: string[] = [];
  const fetcher: typeof fetch = async (url, options) => {
    paths.push(String(url)); assert.equal((options!.headers as any).Authorization, "Bearer test-token");
    if (String(url).includes("matchRewardReceipts")) return Response.json({}, { status: 404 });
    if (String(url).endsWith(":commit")) {
      const body = JSON.parse(options!.body as string); assert.equal(body.writes.length, 4);
      return Response.json({});
    }
    return Response.json(profile(String(url).split("/").at(-1)!));
  };
  assert.equal((await createFirestoreRewardStore("test", async () => "test-token", fetcher).settle(plan)).settled, true);
  assert.ok(paths.some(path => path.endsWith(":commit"))); assert.ok(paths.every(path => !path.includes("batchWrite")));
  await assert.rejects(() => createFirestoreRewardStore("test", async () => "test-token",
    async () => Response.json({ error: { status: "PERMISSION_DENIED" } }, { status: 403 })).settle(plan), /reward_access_denied/);
});
