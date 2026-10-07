import { cut, deal, playCard, startRound, type Card, type MatchState } from "./match_engine.ts";
import { manualPlay, releasePlayer, timeoutPlay } from "./turn_policy.ts";
import { assignBotDifficulties, chooseBotCard } from './bot_strategy.ts';

type Capture = { leadingCard: Card; capturedCards: Card[]; isRoundAward?: boolean };
type Transition = { state: MatchState; deck: Card[] };
function map<T>(value: unknown): Record<string, T> {
  return value && typeof value === "object" && !Array.isArray(value) ? { ...value as Record<string, T> } : {};
}
function integer(value: unknown, fallback = 0) { return Number.isSafeInteger(value) ? value as number : fallback; }
// Resolve once, after human voting closes; bots never submit independent votes.
export function resolveShuffleBotVotes(ids: string[], humanVotes: Record<string, boolean>, random = Math.random) {
  const humans = ids.filter(id => !id.startsWith("bot_") && !id.startsWith("waiting_"));
  const votes: Record<string, boolean> = Object.fromEntries(humans.map(id => [id, humanVotes[id] ?? false]));
  const yes = Object.values(votes).filter(Boolean).length;
  const no = humans.length - yes;
  const bots = ids.filter(id => id.startsWith("bot_"));
  if (!bots.length) return votes;
  const choice = !humans.length ? false : yes === no ? random() < 0.5 : yes > no;
  for (const id of bots) votes[id] = choice;
  return votes;
}
function elapsed(state: MatchState, now: number) {
  const started = Date.parse(String(state.phaseStartedAt ?? state.turnStartTime ?? ""));
  return Number.isFinite(started) ? Math.max(0, now - started) : 0;
}
function stamp(transition: Transition, now: number): Transition {
  return { ...transition, state: { ...transition.state, phaseStartedAt: new Date(now).toISOString() } };
}
function nextRound(state: MatchState, shuffle: boolean, now: number): Transition {
  const started = startRound(state, state.playerIds![0]);
  const prior = map<Capture[]>(state.harvestStacks);
  const restored = ["teamA", "teamB"].flatMap(team => (prior[team] ?? [])
    .flatMap(capture => [...capture.capturedCards, capture.leadingCard]));
  if (!shuffle) {
    const keys = new Set(restored.map(card => `${card.suit}_${card.rank}`));
    if (restored.length !== 52 || keys.size !== 52) throw new Error("invalid_restored_deck");
    started.deck = restored;
  }
  started.state = { ...started.state, roundsSinceLastShuffle: shuffle ? 0 : integer(state.roundsSinceLastShuffle) + 1,
    turnStartTime: new Date(now).toISOString(), capturingCards: [], capturingTeam: null,
    capturingStage: 0, playHistory: [], earnedStars: {}, earnedCoins: {}, expireAt: null,
    settlementPending: false, rewardRoster: [], rewardScores: null, rewardReceiptId: null, rewardCompletedAt: null };
  return stamp({ ...started, state: assignBotDifficulties(started.state) }, now);
}
function finishRound(state: MatchState, deck: Card[], now: number): Transition {
  if (deck.length || !(state.playerIds ?? []).every(uid => !(state.handCards?.[uid] ?? []).length)) {
    throw new Error("round_not_finished");
  }
  const harvest = map<Capture[]>(state.harvestStacks);
  const board = [...(state.board ?? [])];
  const lastTeam = state.lastCaptureTeam === "teamB" ? "teamB" : "teamA";
  if (board.length) harvest[lastTeam] = [...(harvest[lastTeam] ?? []),
    { leadingCard: board[0], capturedCards: board.slice(1), isRoundAward: true }];
  const count = (team: string) => (harvest[team] ?? []).reduce((n, capture) => n + 1 + capture.capturedCards.length, 0);
  const a = count("teamA"), b = count("teamB");
  if (a + b !== 52) throw new Error("round_card_conservation_failed");
  return stamp({ state: { ...state, board: [], harvestStacks: harvest, phase: "roundScoring",
    teamAScore: integer(state.teamAScore) + (a > b ? 3 : 0),
    teamBScore: integer(state.teamBScore) + (b > a ? 3 : 0) }, deck }, now);
}
function animateCapture(before: MatchState, after: MatchState, deck: Card[], now: number): Transition {
  const captured = (before.board ?? []).length > 0 && !(after.board ?? []).length;
  if (!captured) return { state: { ...after, turnStartTime: new Date(now).toISOString() }, deck };
  const team = String(after.lastCaptureTeam);
  const captures = map<Capture[]>(after.harvestStacks)[team] ?? [];
  const leading = captures.at(-1)!.leadingCard;
  return stamp({ state: { ...after, phase: "capturing", capturingStage: 0,
    board: [...(before.board ?? []), leading], capturingCards: [...(before.board ?? []), leading],
    capturingTeam: team, turnStartTime: new Date(now + 1200).toISOString() }, deck }, now);
}

/** All timed transitions use a supplied server clock, never a client clock. */
export function advanceMatch(state: MatchState, deck: Card[], now = Date.now()): Transition {
  state = assignBotDifficulties(state);
  const ids = state.playerIds ?? [];
  if (ids.length !== 4) throw new Error("four_players_required");
  switch (state.phase) {
    case "waitingForPlayers":
      if (ids.some(uid => uid.startsWith("waiting_"))) throw new Error("no_transition_due");
      return nextRound({ ...state, roundCount: 0 }, true, now);
    case "preRoundCut": {
      const cutter = ids[(integer(state.dealerIndex) + 3) % 4];
      if (elapsed(state, now) < (cutter.startsWith("bot_") ? 1000 : (integer(state.timerDurationSeconds) || 15) * 1000)) {
        throw new Error("no_transition_due");
      }
      return stamp(cut(state, deck, cutter, Math.floor(deck.length / 2)), now);
    }
    case "dealingFasha":
      if (elapsed(state, now) < 2000) throw new Error("no_transition_due");
      return stamp(deal(state, deck, ids[integer(state.dealerIndex)], true), now);
    case "dealingCards":
      if (elapsed(state, now) < 5000) throw new Error("no_transition_due");
      return stamp({ state: { ...state, phase: "playing", turnStartTime: new Date(now).toISOString() }, deck }, now);
    case "capturing":
      if (elapsed(state, now) >= 1200) return stamp({ state: { ...state, phase: "playing",
        board: [], capturingCards: [], capturingTeam: null, capturingStage: 0,
        turnStartTime: new Date(now).toISOString() }, deck }, now);
      if (elapsed(state, now) >= 600 && state.capturingStage !== 1) {
        return { state: { ...state, capturingStage: 1 }, deck };
      }
      throw new Error("no_transition_due");
    case "playing": {
      if (ids.every(uid => !(state.handCards?.[uid] ?? []).length)) {
        if (!deck.length) return finishRound(state, deck, now);
        const dealt = deal(state, deck, ids[integer(state.dealerIndex)], false);
        return stamp({ ...dealt, state: { ...dealt.state, turnStartTime: new Date(now).toISOString() } }, now);
      }
      const uid = ids[integer(state.currentTurnIndex)];
      const started = Date.parse(String(state.turnStartTime ?? ""));
      if (uid.startsWith("bot_")) {
        if (!Number.isFinite(started) || now - started < 1000) throw new Error("no_transition_due");
        const hand = state.handCards?.[uid] ?? [];
        if (!hand.length) throw new Error("empty_hand");
        const card = chooseBotCard(state, uid);
        return animateCapture(state, playCard(state, uid, card), deck, now);
      }
      return animateCapture(state, timeoutPlay(state, now), deck, now);
    }
    case "roundScoring": {
      if (elapsed(state, now) < 5000) throw new Error("no_transition_due");
      if (integer(state.teamAScore) >= integer(state.maxPoints, 41) || integer(state.teamBScore) >= integer(state.maxPoints, 41)) {
        const winner = integer(state.teamAScore) >= integer(state.maxPoints, 41) ? 0 : 1;
        const stars: Record<string, number> = {}, coins: Record<string, number> = {};
        ids.forEach((uid, seat) => { if (!uid.startsWith("bot_")) {
          stars[uid] = seat % 2 === winner ? 50 : -30; coins[uid] = seat % 2 === winner ? 100 : 20;
        }});
        return stamp({ state: { ...state, phase: "rematchVoting", rematchVotes: {},
          earnedStars: stars, earnedCoins: coins, settlementPending: true,
          rewardCompletedAt: new Date(now).toISOString(),
          rewardRoster: [...ids], rewardScores: { teamA: integer(state.teamAScore), teamB: integer(state.teamBScore) } }, deck }, now);
      }
      const rounds = integer(state.roundsSinceLastShuffle);
      if (rounds >= 5) return nextRound(state, true, now);
      if (rounds >= 2) return stamp({ state: { ...state, phase: "shuffleVoting", shuffleVotes: {} }, deck }, now);
      return nextRound(state, false, now);
    }
    case "shuffleVoting":
    case "rematchVoting": {
      const rematch = state.phase === "rematchVoting";
      const field = rematch ? "rematchVotes" : "shuffleVotes";
      const votes = map<boolean>(state[field]);
      const humans = ids.filter(uid => !uid.startsWith("bot_") && !uid.startsWith("waiting_"));
      const timedOut = elapsed(state, now) >= 10000;
      if (timedOut) humans.forEach(uid => { if (!(uid in votes)) votes[uid] = false; });
      const all = humans.length > 0 && humans.every(uid => uid in votes);
      const refused = humans.some(uid => votes[uid] === false);
      if (timedOut || all) {
        if (rematch) {
          if (refused || !all) return { state: { ...state, phase: "matchOver", rematchVotes: votes }, deck };
          // Settlement must complete before any rematch discards its reward record.
          if (state.settlementPending === true) throw new Error("settlement_pending");
          return nextRound({ ...state, teamAScore: 0, teamBScore: 0, roundCount: 0,
            matchSequence: integer(state.matchSequence) + 1 }, true, now);
        }
        const resolved = resolveShuffleBotVotes(ids, votes);
        const next = nextRound(state, !refused && all, now);
        return { ...next, state: { ...next.state, shuffleVotes: resolved } };
      }
      if (JSON.stringify(votes) !== JSON.stringify(state[field] ?? {})) return { state: { ...state, [field]: votes }, deck };
      throw new Error("no_transition_due");
    }
    default: throw new Error("no_transition_due");
  }
}

export function lifecycleCommand(type: string, state: MatchState, deck: Card[], uid: string,
  payload: Record<string, unknown>, now = Date.now()): Transition {
  if (!(state.playerIds ?? []).includes(uid) || uid.startsWith("bot_") || uid.startsWith("waiting_")) {
    throw new Error("human_participant_required");
  }
  if (type === "advance") return advanceMatch(state, deck, now);
  if (type === "playCard") return animateCapture(state, manualPlay(state, uid, payload.card, now), deck, now);
  if (type === "leave") return { state: releasePlayer(state, uid, "left"), deck };
  if (type === "cut") {
    if (state.phase !== "preRoundCut") throw new Error("cut_not_ready");
    // The timer-free gameplay option still has a bounded preparation phase.
    const seconds = integer(state.timerDurationSeconds) || 15;
    if (elapsed(state, now) >= seconds * 1000) throw new Error("cut_deadline_reached");
    return stamp(cut(state, deck, uid, payload.position), now);
  }
  if (type === "voteShuffle" || type === "voteRematch") {
    const rematch = type === "voteRematch";
    if (state.phase !== (rematch ? "rematchVoting" : "shuffleVoting") || typeof payload.vote !== "boolean") {
      throw new Error("invalid_vote");
    }
    const field = rematch ? "rematchVotes" : "shuffleVotes";
    if (elapsed(state, now) >= 10000) throw new Error("vote_deadline_reached");
    const votes = map<boolean>(state[field]);
    if (uid in votes) throw new Error("already_voted");
    return { state: { ...state, [field]: { ...votes, [uid]: payload.vote } }, deck };
  }
  if (type === "voteForBots") {
    if (state.phase !== "waitingForPlayers") throw new Error("room_not_waiting");
    const votes = { ...map<boolean>(state.botInjectionVotes), [uid]: true };
    const humans = state.playerIds!.filter(id => !id.startsWith("waiting_") && !id.startsWith("bot_"));
    const next = { ...state, botInjectionVotes: votes };
    if (humans.every(id => votes[id])) {
      next.playerIds = state.playerIds!.map((id, seat) => id.startsWith("waiting_") ? `bot_${seat + 1}` : id);
      next.players = Object.fromEntries(next.playerIds.map(id => [id, true]));
      next.playerNames = { ...map<string>(state.playerNames),
        ...Object.fromEntries(next.playerIds.filter(id => id.startsWith("bot_")).map(id => [id, "bot_name_template"])) };
    }
    return { state: assignBotDifficulties(next), deck };
  }
  throw new Error("unsupported_command");
}
