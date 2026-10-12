import type { MatchState } from './match_engine.ts';

export const BOT_THINK_MS = 450;
export const FORCED_CARD_MS = 600;
export const CAPTURE_MS = 600;

/** Pure server deadline policy. No credentials, cards or browser presence in jobs. */
export function progressDeadline(state: MatchState): number | null {
  const ids = state.playerIds ?? [];
  if (ids.length !== 4 || !ids.some(id => !/^(bot_|waiting_)/.test(id))) return null;
  const phase = String(state.phase);
  const phaseStart = Date.parse(String(state.phaseStartedAt ?? state.turnStartTime ?? ''));
  const turnStart = Date.parse(String(state.turnStartTime ?? ''));
  const clock = (start: number, duration: number) => Number.isFinite(start) ? start + duration : null;
  const timer = Number(state.timerDurationSeconds ?? 10);
  switch (phase) {
    case 'waitingForPlayers': return ids.some(id => id.startsWith('waiting_')) ? null : 0;
    case 'preRoundCut':
      return clock(phaseStart, ids[(Number(state.dealerIndex) + 3) % 4].startsWith('bot_') ? 1000 : (timer > 0 ? timer : 15) * 1000);
    case 'dealingFasha': return clock(phaseStart, 2000);
    case 'dealingCards': case 'roundScoring': return clock(phaseStart, 5000);
    case 'capturing': return clock(phaseStart, CAPTURE_MS);
    case 'playing': {
      const counts = state.handCounts as Record<string, number> ?? {};
      const count = (id: string) => state.handCards?.[id]?.length ?? counts[id] ?? 0;
      if (ids.every(id => count(id) === 0)) return 0;
      const active = ids[Number(state.currentTurnIndex)];
      if (!active) return null;
      if (count(active) === 1) return clock(turnStart, FORCED_CARD_MS);
      if (active.startsWith('bot_')) return clock(turnStart, BOT_THINK_MS);
      return timer > 0 ? clock(turnStart, timer * 1000) : null;
    }
    case 'shuffleVoting': case 'rematchVoting': {
      const votes = state[phase === 'rematchVoting' ? 'rematchVotes' : 'shuffleVotes'] as Record<string, boolean> ?? {};
      const humans = ids.filter(id => !/^(bot_|waiting_)/.test(id));
      const all = humans.every(id => typeof votes[id] === 'boolean');
      if (phase === 'rematchVoting' && all && humans.every(id => votes[id]) && state.settlementPending === true) return null;
      return all ? 0 : clock(phaseStart, 10000);
    }
    default: return null;
  }
}

export function progressEnabled(config: Record<string, unknown> | undefined, id: string) {
  return /^[A-Z]{3}[0-9]{5}$/.test(id) &&
    (config?.progress_enabled === true || config?.progress_canary_room_id === id);
}
