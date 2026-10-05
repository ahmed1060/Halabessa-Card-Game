import { waitingSeatIndex, type MatchState } from "./match_engine.ts";
import { claimReplacement } from "./turn_policy.ts";

type Profile = { displayName: string; cardBackId: string; avatarUrl: string };
function record(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? { ...value as Record<string, unknown> } : {};
}

/** Call only on the current SQL state under the room/secrets row lock. */
export function joinCommandRoom(state: MatchState, uid: string, profile: Profile, now = Date.now()) {
  const ids = state.playerIds;
  if (!uid || uid.startsWith("bot_") || uid.startsWith("waiting_")) throw new Error("human_seat_required");
  if (!Array.isArray(ids) || ids.length !== 4) throw new Error("invalid_room_state");
  const existing = ids.indexOf(uid);
  if (existing >= 0) return { state, seatIndex: existing, alreadyJoined: true };
  if (typeof state.expireAt === "string" && Date.parse(state.expireAt) <= now) throw new Error("room_not_joinable");
  if (state.phase !== "waitingForPlayers") {
    const next = claimReplacement(state, uid, profile);
    // Recovery must give the incoming active human a full turn, not inherit
    // an expired bot timestamp and immediately incur a timeout.
    if (next.playerIds!.indexOf(uid) === Number(next.currentTurnIndex)) {
      next.turnStartTime = new Date(now).toISOString();
    }
    return { state: next, seatIndex: next.playerIds!.indexOf(uid), alreadyJoined: false };
  }
  const seat = waitingSeatIndex(ids);
  if (seat < 0) throw new Error("room_full");
  const seats = [...ids];
  const placeholder = seats[seat]; seats[seat] = uid;
  const next: MatchState = { ...state, playerIds: seats, botInjectionVotes: {} };
  for (const [field, value] of Object.entries({ players: true, playerNames: profile.displayName,
    playerSkins: profile.cardBackId, playerAvatars: profile.avatarUrl, playerOnlineStatus: true })) {
    const values = record(state[field]); delete values[placeholder]; values[uid] = value; next[field] = values;
  }
  const hands = { ...(state.handCards ?? {}) }; delete hands[placeholder]; hands[uid] = [];
  next.handCards = hands;
  next.consecutiveTimeouts = { ...record(state.consecutiveTimeouts), [uid]: 0 };
  return { state: next, seatIndex: seat, alreadyJoined: false };
}
