import { playCard, type Card, type MatchState } from "./match_engine.ts";
import { assignBotDifficulties } from './bot_strategy.ts';

function record<T>(value: unknown): Record<string, T> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? { ...value as Record<string, T> } : {};
}

/** Preserve the seat/team and cards; disconnection alone never calls this. */
export function releasePlayer(state: MatchState, uid: string, reason: "left" | "inactivity") {
  const seats = [...(state.playerIds ?? [])];
  const seat = seats.indexOf(uid);
  if (seat < 0 || uid.startsWith("bot_") || uid.startsWith("waiting_")) {
    throw new Error("human_seat_required");
  }
  const waiting = state.phase === "waitingForPlayers";
  const bot = waiting ? `waiting_${seat}` : `bot_${seat + 1}_replacement_${Number(state.serverVersion ?? 0) + 1}`;
  seats[seat] = bot;
  const hands = record<Card[]>(state.handCards);
  hands[bot] = [...(hands[uid] ?? [])];
  delete hands[uid];
  const players = record<boolean>(state.players);
  delete players[uid]; if (!waiting) players[bot] = true;
  const names = record<string>(state.playerNames);
  delete names[uid]; if (!waiting) names[bot] = "bot_name_template";
  const online = record<boolean>(state.playerOnlineStatus);
  delete online[uid]; if (!waiting) online[bot] = true;
  const replacements = record<{ previousUid: string; reason: string }>(state.releasedSeats);
  if (!waiting) replacements[bot] = { previousUid: uid, reason };
  const counts = record<number>(state.consecutiveTimeouts);
  delete counts[uid];
  const next: MatchState = { ...state, playerIds: seats, players, handCards: hands,
    handCounts: Object.fromEntries(Object.entries(hands).map(([id, cards]) => [id, cards.length])),
    playerNames: names, playerOnlineStatus: online, releasedSeats: replacements,
    consecutiveTimeouts: counts };
  // A vacated controller must never remain an actor in per-player state.
  for (const field of ["playerSkins", "playerAvatars", "playerEmojis", "playerLastActive",
    "shuffleVotes", "rematchVotes", "botInjectionVotes", "skippedMatches"]) {
    const values = record<unknown>(state[field]);
    if (field === "skippedMatches" && values[uid]) values[bot] = values[uid];
    delete values[uid]; next[field] = values;
  }
  const ownership = record<string>(state.cardOwnership);
  for (const key of Object.keys(ownership)) if (ownership[key] === uid) ownership[key] = bot;
  next.cardOwnership = ownership;
  // Tafweet records refer to the controller that supplied a skipped rank.
  const skips = record<string[]>(next.skippedMatches);
  for (const id of Object.keys(skips)) {
    skips[id] = skips[id].map(skip => skip.endsWith(`:${uid}`) ? `${skip.slice(0, -(uid.length + 1))}:${bot}` : skip);
  }
  next.skippedMatches = skips;
  return assignBotDifficulties(next);
}

/** Server wall time decides timeout eligibility, never a client-supplied flag. */
export function timeoutPlay(state: MatchState, now = Date.now()) {
  if (state.phase !== "playing") throw new Error("play_not_ready");
  const uid = state.playerIds?.[Number(state.currentTurnIndex)];
  if (!uid || uid.startsWith("bot_") || uid.startsWith("waiting_")) {
    throw new Error("human_turn_required");
  }
  const started = typeof state.turnStartTime === "string" ? Date.parse(state.turnStartTime) : NaN;
  const duration = Number(state.timerDurationSeconds);
  if (!Number.isFinite(started) || !Number.isFinite(duration) || duration <= 0 ||
      now < started + duration * 1000) throw new Error("turn_deadline_not_reached");
  const hand = state.handCards?.[uid] ?? [];
  if (!hand.length) throw new Error("empty_hand");
  const top = state.board?.at(-1);
  const card = hand.find((candidate) => candidate.rank === top?.rank) ?? hand[0];
  const played = playCard(state, uid, card);
  const counts = record<number>(state.consecutiveTimeouts);
  const count = Number(counts[uid] ?? 0) + 1;
  const next: MatchState = { ...played, turnStartTime: new Date(now).toISOString(),
    consecutiveTimeouts: { ...counts, [uid]: count } };
  return count >= 3 ? releasePlayer(next, uid, "inactivity") : next;
}

export function manualPlay(state: MatchState, uid: string, card: unknown, now = Date.now()) {
  const duration = Number(state.timerDurationSeconds);
  const started = Date.parse(String(state.turnStartTime ?? ""));
  if (duration > 0 && (!Number.isFinite(started) || now >= started + duration * 1000)) {
    throw new Error("turn_deadline_reached");
  }
  // Rejected or unowned-card requests do not reset the inactivity streak.
  const played = playCard(state, uid, card);
  const counts = record<number>(state.consecutiveTimeouts);
  counts[uid] = 0;
  return { ...played, consecutiveTimeouts: counts } as MatchState;
}

/** Use only with the current state locked in the room transaction. */
export function claimReplacement(state: MatchState, uid: string, profile: {
  displayName: string; cardBackId: string; avatarUrl: string;
}) {
  if (!uid || uid.startsWith("bot_") || uid.startsWith("waiting_")) throw new Error("human_seat_required");
  if ((state.playerIds ?? []).includes(uid)) throw new Error("already_seated");
  const seat = replacementSeatIndex(state);
  if (seat < 0) throw new Error("no_safe_replacement_seat");
  const seats = [...state.playerIds!];
  const bot = seats[seat];
  seats[seat] = uid;
  const next: MatchState = { ...state, playerIds: seats };
  for (const field of ["handCards", "handCounts", "players", "skippedMatches"]) {
    const values = record<unknown>(state[field]);
    if (bot in values) values[uid] = values[bot];
    delete values[bot]; next[field] = values;
  }
  for (const [field, value] of Object.entries({ playerNames: profile.displayName,
    playerSkins: profile.cardBackId, playerAvatars: profile.avatarUrl, playerOnlineStatus: true })) {
    const values = record<unknown>(state[field]);
    delete values[bot]; values[uid] = value; next[field] = values;
  }
  const released = record<unknown>(state.releasedSeats);
  delete released[bot]; next.releasedSeats = released;
  next.consecutiveTimeouts = { ...record<number>(state.consecutiveTimeouts), [uid]: 0 };
  const ownership = record<string>(state.cardOwnership);
  for (const key of Object.keys(ownership)) if (ownership[key] === bot) ownership[key] = uid;
  next.cardOwnership = ownership;
  const skips = record<string[]>(next.skippedMatches);
  for (const id of Object.keys(skips)) {
    skips[id] = skips[id].map(skip => skip.endsWith(`:${bot}`) ? `${skip.slice(0, -(bot.length + 1))}:${uid}` : skip);
  }
  next.skippedMatches = skips;
  return next;
}

/** Initial bots are not replacement vacancies; claim only explicitly released seats. */
export function replacementSeatIndex(state: MatchState) {
  return replacementSeatIndices(state)[0] ?? -1;
}

export function replacementSeatIndices(state: MatchState) {
  if (!state.isPublic || !replacementPhaseAvailable(state)) return [];
  const released = record<unknown>(state.releasedSeats);
  // An all-bot room has no human who can request advances. Permit recovery of
  // its explicitly released active seat under the same room transaction lock.
  const ids = state.playerIds ?? [];
  const unattended = ids.length === 4 && ids.every(uid => uid.startsWith("bot_"));
  return ids.flatMap((uid, index) =>
    uid.startsWith("bot_") && uid in released && (unattended || index !== Number(state.currentTurnIndex)) ? [index] : []);
}

/** Only live preparation/animation phases may recover an unattended room.
 * Voting, scoring and results are excluded to avoid joining a settled roster. */
export function replacementPhaseAvailable(state: MatchState) {
  if (state.phase === "playing") return true;
  const ids = state.playerIds ?? [];
  return ids.length === 4 && ids.every(uid => uid.startsWith("bot_")) &&
    ["preRoundCut", "dealingFasha", "dealingCards", "capturing"].includes(String(state.phase));
}
