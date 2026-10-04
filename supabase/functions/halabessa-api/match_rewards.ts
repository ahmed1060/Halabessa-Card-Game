import type { MatchState } from "./match_engine.ts";

export type Reward = { uid: string; points: number; coins: number; won: boolean; teamScore: number };
export type ProfileDocument = { name: string; updateTime: string; fields: Record<string, Record<string, unknown>> };
export type RewardPlan = { receiptId: string; fingerprint: string; rewards: Reward[] };
const statFields = ["points", "coins", "wins", "losses", "gamesPlayed", "bestScore"];
function integer(value: unknown) {
  if (!Number.isSafeInteger(value) || Number(value) < 0) throw new Error("invalid_reward_state");
  return value as number;
}
async function digest(value: string) {
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(hash), byte => byte.toString(16).padStart(2, "0")).join("");
}

/** Never award legacy/client-supplied snapshots. Roster and scores were frozen
 * by the SQL lifecycle at completion, so later departures cannot alter awards.
 */
export async function rewardPlan(state: MatchState, roomCreatedAt: string): Promise<RewardPlan> {
  if (state.protocolVersion !== 1 || state.settlementPending !== true ||
      !["rematchVoting", "matchOver"].includes(String(state.phase))) throw new Error("rewards_not_ready");
  if (!/^[A-Z]{3}[0-9]{5}$/.test(String(state.id)) || !roomCreatedAt) throw new Error("invalid_reward_state");
  const sequence = integer(state.matchSequence ?? 0);
  const scores = state.rewardScores as Record<string, unknown> | undefined;
  const roster = state.rewardRoster;
  if (!scores || !Array.isArray(roster) || roster.length !== 4) throw new Error("invalid_reward_state");
  const a = integer(scores.teamA), b = integer(scores.teamB), target = integer(state.maxPoints);
  if (target <= 0 || (a < target && b < target)) throw new Error("invalid_reward_state");
  const winner = a >= target ? 0 : 1;
  const ids = new Set<string>();
  const rewards: Reward[] = roster.flatMap((uid, seat) => {
    if (typeof uid !== "string" || !/^[A-Za-z0-9:_-]{1,128}$/.test(uid) || uid.startsWith("waiting_") || ids.has(uid)) {
      throw new Error("invalid_reward_state");
    }
    ids.add(uid);
    if (uid.startsWith("bot_")) return [];
    const won = seat % 2 === winner;
    return [{ uid, points: won ? 50 : -30, coins: won ? 100 : 20, won, teamScore: seat % 2 === 0 ? a : b }];
  });
  const receiptId = await digest(`${state.id}\0${roomCreatedAt}\0${sequence}`);
  const fingerprint = await digest(JSON.stringify({ roomId: state.id, sequence, a, b, roster, rewards }));
  return { receiptId, fingerprint, rewards };
}

function stat(document: ProfileDocument, field: string) {
  const value = document.fields[field];
  if (value == null) return 0;
  const n = value.integerValue != null ? Number(value.integerValue) : value.doubleValue;
  if (!Number.isSafeInteger(n) || Number(n) < 0) throw new Error("invalid_reward_profile");
  return Number(n);
}
export function rewardWrites(base: string, plan: RewardPlan, profiles: ProfileDocument[]) {
  if (profiles.length !== plan.rewards.length) throw new Error("reward_profile_missing");
  const writes: Record<string, unknown>[] = plan.rewards.map((reward, index) => {
    const profile = profiles[index];
    if (profile.name !== `${base}/users/${reward.uid}` || !profile.updateTime ||
        !profile.fields || typeof profile.fields !== "object") throw new Error("invalid_reward_profile");
    const values = {
      points: Math.max(0, Math.min(999999, stat(profile, "points") + reward.points)),
      coins: stat(profile, "coins") + reward.coins,
      wins: stat(profile, "wins") + (reward.won ? 1 : 0),
      losses: stat(profile, "losses") + (reward.won ? 0 : 1),
      gamesPlayed: stat(profile, "gamesPlayed") + 1,
      bestScore: Math.max(stat(profile, "bestScore"), reward.teamScore),
    };
    if (Object.values(values).some(value => !Number.isSafeInteger(value))) throw new Error("invalid_reward_profile");
    return { update: { name: profile.name, fields: Object.fromEntries(Object.entries(values)
      .map(([field, value]) => [field, { integerValue: String(value) }])) },
      updateMask: { fieldPaths: statFields }, currentDocument: { updateTime: profile.updateTime } };
  });
  writes.push({ update: { name: `${base}/matchRewardReceipts/${plan.receiptId}`,
    fields: { fingerprint: { stringValue: plan.fingerprint } } },
    currentDocument: { exists: false },
    updateTransforms: [{ fieldPath: "settledAt", setToServerValue: "REQUEST_TIME" }] });
  return writes;
}

export type RewardStore = {
  readReceipt: (id: string) => Promise<string | null>;
  readProfiles: (uids: string[]) => Promise<ProfileDocument[]>;
  commit: (writes: Record<string, unknown>[]) => Promise<void>;
};
/** A conditional receipt create and all profile updates are one atomic commit.
 * Re-read after an ambiguous response or a competing profile write. Never use
 * an unconditional batchWrite or overwrite wallets from a SQL shadow profile.
 */
export async function settleRewardPlan(base: string, plan: RewardPlan, store: RewardStore) {
  for (let attempt = 0; attempt < 2; attempt++) {
    const prior = await store.readReceipt(plan.receiptId);
    if (prior != null) {
      if (prior !== plan.fingerprint) throw new Error("reward_receipt_conflict");
      return { settled: true, duplicate: true };
    }
    const profiles = await store.readProfiles(plan.rewards.map(reward => reward.uid));
    try {
      await store.commit(rewardWrites(base, plan, profiles));
      return { settled: true, duplicate: false };
    } catch (error) {
      // Permission/schema errors are not transient. Only a conflict or an
      // ambiguous network result can be reconciled against the receipt.
      if (!(error instanceof Error) || !["reward_commit_conflict", "reward_transport_failed"].includes(error.message)) throw error;
    }
  }
  const prior = await store.readReceipt(plan.receiptId);
  if (prior === plan.fingerprint) return { settled: true, duplicate: true };
  if (prior != null) throw new Error("reward_receipt_conflict");
  throw new Error("reward_settlement_retry_required");
}
