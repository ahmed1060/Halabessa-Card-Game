import type { MatchState } from './match_engine.ts';

/** Presentation capability is negotiated per authenticated participant, never
 * used as gameplay authority. Missing/older clients keep the legacy phase. */
export function declareCapturePresentation(state: MatchState, uid: string, version: unknown): MatchState {
  const saved = state.capturePresentationByPlayer;
  const capabilities = saved && typeof saved === 'object' && !Array.isArray(saved)
    ? { ...saved as Record<string, number> } : {};
  capabilities[uid] = version === 2 ? 2 : 1;
  const ids = state.playerIds ?? [];
  return { ...state, capturePresentationByPlayer: Object.fromEntries(
    ids.filter(id => !/^(bot_|waiting_)/.test(id)).map(id => [id, capabilities[id] ?? 1])) };
}

export function atomicCaptureSupported(state: MatchState): boolean {
  const humans = (state.playerIds ?? []).filter(id => !/^(bot_|waiting_)/.test(id));
  const capabilities = state.capturePresentationByPlayer as Record<string, unknown> | undefined;
  return state.protocolVersion === 1 && humans.length > 0 &&
    humans.every(uid => capabilities?.[uid] === 2);
}
