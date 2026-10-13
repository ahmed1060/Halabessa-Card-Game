import type { MatchState } from './match_engine.ts';

export function hasHumanController(state: MatchState) {
  return (state.playerIds ?? []).some(id => !/^(bot_|waiting_)/.test(id));
}

/** A confirmed leave/kick, not presence loss, can close an empty room. */
export function closeEmptyRoom(state: MatchState, now = Date.now()): MatchState {
  if (hasHumanController(state)) return state;
  return { ...state, roomClosed: true, closureReason: 'no_humans',
    phase: 'matchOver', isPublic: false, playerIds: [], players: {},
    board: [], handCards: {}, handCounts: {}, deckCount: 0,
    capturingCards: [], capturingTeam: null, capturingStage: 0,
    captureEvents: [], cutLastCard: null, lastCardRevealed: null,
    playerNames: {}, playerSkins: {}, playerAvatars: {}, botDifficulties: {},
    playerOnlineStatus: {}, playerLastActive: {}, playerEmojis: {},
    playerEmojiExpiresAt: {}, releasedSeats: {}, cardOwnership: {},
    skippedMatches: {}, playHistory: [], harvestStacks: {},
    shuffleVotes: {}, rematchVotes: {}, botInjectionVotes: {},
    capturePresentationByPlayer: {}, progressDueAt: null, playAvailableAt: null,
    closedAt: new Date(now).toISOString(),
    // Never discard a completed match's unsettled reward snapshot.
    expireAt: null };
}
