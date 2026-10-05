import { lifecycleCommand } from "./match_lifecycle.ts";
import type { Card, MatchState } from "./match_engine.ts";

export const matchCommandTypes = new Set([
  "advance", "playCard", "cut", "leave", "voteShuffle", "voteRematch", "voteForBots",
  "startRound", "dealInitial", "beginPlay", "dealSubsequent",
  "updateProfile", "sendEmoji",
]);

/** The verified JWT caller is the actor. Nobody proxies another human or bot.
 * Bot decisions and timed phases are requested with advance and chosen by the
 * server. Compatibility phase names cannot bypass those same timing checks.
 */
export function executeMatchIntent(type: string, state: MatchState, deck: Card[],
  callerUid: string, requestedActor: string, payload: Record<string, unknown>, now = Date.now()) {
  if (requestedActor !== callerUid) throw new Error("invalid_command_actor");
  if (!matchCommandTypes.has(type)) throw new Error("unsupported_command");
  if (type === "updateProfile" || type === "sendEmoji") {
    if (!(state.playerIds ?? []).includes(callerUid) || /^(bot_|waiting_)/.test(callerUid)) {
      throw new Error("human_participant_required");
    }
    const next = structuredClone(state);
    const values = (key: string) => ({ ...(next[key] as Record<string, string> ?? {}) });
    if (type === "sendEmoji") {
      const allowed = new Set(["👑", "😎", "🔥", "💪", "😂", "🤔", "😱", "👋"]);
      if (typeof payload.emoji !== "string" || !allowed.has(payload.emoji)) throw new Error("invalid_emoji");
      const expiry = Date.parse(values("playerEmojiExpiresAt")[callerUid] ?? "");
      if (Number.isFinite(expiry) && now < expiry - 2000) throw new Error("emoji_rate_limited");
      next.playerEmojis = { ...values("playerEmojis"), [callerUid]: payload.emoji };
      next.playerEmojiExpiresAt = { ...values("playerEmojiExpiresAt"), [callerUid]: new Date(now + 3000).toISOString() };
    } else {
      const name = payload.displayName;
      const skin = payload.cardBackId;
      const avatar = payload.avatarUrl;
      if (typeof name !== "string" || !name.trim() || name.length > 80 || /[\u0000-\u001f\u007f]/.test(name) ||
          typeof skin !== "string" || !/^[a-zA-Z0-9_-]{1,64}$/.test(skin) ||
          typeof avatar !== "string" || avatar.length > 2048 ||
          (avatar !== "" && !/^assets\/images\/avatars\/[a-zA-Z0-9_-]+\.(png|jpg|jpeg|webp)$/.test(avatar) &&
            !/^https:\/\/[^\s]+$/.test(avatar))) throw new Error("invalid_profile");
      next.playerNames = { ...values("playerNames"), [callerUid]: name.trim() };
      next.playerSkins = { ...values("playerSkins"), [callerUid]: skin };
      next.playerAvatars = { ...values("playerAvatars"), [callerUid]: avatar };
    }
    // Presentation-only: never accept hand, seat, wallet or timing fields.
    return { state: next, deck };
  }
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
