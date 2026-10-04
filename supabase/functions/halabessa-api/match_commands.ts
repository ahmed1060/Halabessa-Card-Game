import { lifecycleCommand } from "./match_lifecycle.ts";
import type { Card, MatchState } from "./match_engine.ts";

export const matchCommandTypes = new Set([
  "advance", "playCard", "cut", "leave", "voteShuffle", "voteRematch", "voteForBots",
  "startRound", "dealInitial", "beginPlay", "dealSubsequent",
]);

/** The verified JWT caller is the actor. Nobody proxies another human or bot.
 * Bot decisions and timed phases are requested with advance and chosen by the
 * server. Compatibility phase names cannot bypass those same timing checks.
 */
export function executeMatchIntent(type: string, state: MatchState, deck: Card[],
  callerUid: string, requestedActor: string, payload: Record<string, unknown>, now = Date.now()) {
  if (requestedActor !== callerUid) throw new Error("invalid_command_actor");
  if (!matchCommandTypes.has(type)) throw new Error("unsupported_command");
  const requiredPhase: Record<string, string> = {
    startRound: "waitingForPlayers", dealInitial: "dealingFasha",
    beginPlay: "dealingCards", dealSubsequent: "playing",
  };
  if (type in requiredPhase) {
    if (state.phase !== requiredPhase[type]) throw new Error("phase_not_ready");
    if (type === "dealSubsequent" && (state.playerIds ?? []).some(uid => (state.handCards?.[uid] ?? []).length)) {
      throw new Error("hands_not_empty");
    }
    return lifecycleCommand("advance", state, deck, callerUid, {}, now);
  }
  return lifecycleCommand(type, state, deck, callerUid, payload, now);
}
