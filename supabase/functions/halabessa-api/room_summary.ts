import type { MatchState } from "./match_engine.ts";
import { replacementPhaseAvailable, replacementSeatIndices } from "./turn_policy.ts";

/** Index only availability, never private cards or released users' identities. */
export function roomSummary(state: Record<string, unknown>) {
  const ids = Array.isArray(state.playerIds) ? state.playerIds.filter((id): id is string => typeof id === "string") : [];
  const released = state.releasedSeats && typeof state.releasedSeats === "object" && !Array.isArray(state.releasedSeats)
    ? state.releasedSeats as Record<string, unknown> : {};
  const replacements = state.protocolVersion === 1 && state.isPublic === true && replacementPhaseAvailable(state as MatchState)
    ? ids.filter(uid => uid.startsWith("bot_") && uid in released).length : 0;
  return {
    mode: state.mode, playerIds: ids, isPublic: state.isPublic, phase: state.phase,
    protocolVersion: state.protocolVersion ?? 0,
    openSeatCount: state.phase === "waitingForPlayers" ? ids.filter(uid => uid.startsWith("waiting_")).length : replacements,
    replacementSeatCount: replacements,
    safeReplacementSeatCount: replacements ? replacementSeatIndices(state as MatchState).length : 0,
    ...(typeof state.expireAt === "string" ? { expireAt: state.expireAt } : {}),
  };
}
