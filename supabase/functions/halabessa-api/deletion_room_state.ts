import {releasePlayer} from './turn_policy.ts';
import type {MatchState} from './match_engine.ts';

const referenceFields = ['uid','senderId','playerId','playerUid','playedBy','actorUid','previousUid','ownerUid','hostUid'];
const identityMaps = ['players','handCards','handCounts','shuffleVotes','rematchVotes','botInjectionVotes',
  'consecutiveTimeouts','earnedStars','earnedCoins','skippedMatches','playerNames','playerAvatars',
  'playerSkins','playerEmojis','playerEmojiExpiresAt','playerLastActive','playerOnlineStatus'];
export function roomReferencesDeletedPlayer(state: MatchState, uid: string) {
  if (['playerIds','rewardRoster'].some(field => Array.isArray(state[field]) && state[field].includes(uid))) return true;
  if (identityMaps.some(field => state[field] && typeof state[field] === 'object' && uid in state[field])) return true;
  if (state.cardOwnership && typeof state.cardOwnership === 'object' && Object.values(state.cardOwnership).includes(uid)) return true;
  if (state.skippedMatches && typeof state.skippedMatches === 'object' && Object.values(state.skippedMatches)
    .some(values => Array.isArray(values) && values.some(v => typeof v === 'string' && v.endsWith(`:${uid}`)))) return true;
  function attributed(value: unknown): boolean {
    if (Array.isArray(value)) return value.some(attributed);
    if (!value || typeof value !== 'object') return false;
    const row = value as Record<string, unknown>;
    return referenceFields.some(field => row[field] === uid) || Object.values(row).some(attributed);
  }
  return attributed(state);
}

/** Pure room cleanup, invoked only after pending rewards have been settled and
 * with the authoritative room/secret rows locked. Preserve cards/team/score and
 * use normal leave semantics; do not reset or delete another player's match.
 */
export function anonymizeDeletedPlayer(state: MatchState, uid: string, anonymousId: string) {
  if (!/^bot_deleted_[a-f0-9]{32}$/.test(anonymousId) || !uid ||
      uid === anonymousId || (state.playerIds ?? []).includes(anonymousId)) {
    throw new Error('invalid_deletion_anonymous_id');
  }
  if (state.protocolVersion !== 1) throw new Error('unsupported_deletion_room');
  // Frozen settlement rosters must never be edited before exactly-once credit.
  if (state.settlementPending === true) throw new Error('deletion_settlement_required');
  const next = (state.playerIds ?? []).includes(uid)
    ? releasePlayer(state,uid,'left') : structuredClone(state);
  function scrub(value: unknown): unknown {
    if (Array.isArray(value)) return value.map(scrub);
    if (!value || typeof value !== 'object') return value;
    const original = value as Record<string,unknown>;
    const attributed = referenceFields.some(field => original[field] === uid);
    return Object.fromEntries(Object.entries(original).map(([key,entry]) => {
      if (referenceFields.includes(key) && entry === uid) entry = anonymousId;
      if (attributed && ['displayName','senderName','playerName','name'].includes(key)) entry = 'Deleted player';
      if (attributed && ['avatarUrl','photoUrl','email'].includes(key)) entry = '';
      return [key,scrub(entry)];
    }));
  }
  const result = scrub(next) as MatchState;
  // Only schema-defined identity fields are rewritten. A custom UID can be
  // "king", or equal another player's display name; global string replacement
  // would corrupt real cards and unrelated profile/skin values.
  for (const field of ['playerIds','rewardRoster']) {
    const values = result[field];
    if (Array.isArray(values)) result[field] = values.map(value => value === uid ? anonymousId : value);
  }
  for (const field of ['players','handCards','handCounts','shuffleVotes','rematchVotes','botInjectionVotes',
    'consecutiveTimeouts','earnedStars','earnedCoins','skippedMatches']) {
    const map = result[field];
    if (map && typeof map === 'object' && !Array.isArray(map) && uid in map) {
      const values = map as Record<string,unknown>;
      values[anonymousId] = values[uid]; delete values[uid];
    }
  }
  const ownership = result.cardOwnership;
  if (ownership && typeof ownership === 'object' && !Array.isArray(ownership)) {
    for (const [key,value] of Object.entries(ownership)) {
      if (value === uid) (ownership as Record<string,unknown>)[key] = anonymousId;
    }
  }
  const skips = result.skippedMatches;
  if (skips && typeof skips === 'object' && !Array.isArray(skips)) {
    for (const [key,values] of Object.entries(skips)) {
      if (Array.isArray(values)) (skips as Record<string,unknown>)[key] = values.map(value =>
        typeof value === 'string' && value.endsWith(`:${uid}`)
          ? `${value.slice(0,-uid.length)}${anonymousId}` : value);
    }
  }
  for (const field of ['playerNames','playerAvatars','playerSkins','playerEmojis','playerEmojiExpiresAt','playerLastActive','playerOnlineStatus']) {
    const map = result[field];
    if (map && typeof map === 'object' && !Array.isArray(map)) {
      delete (map as Record<string,unknown>)[uid];
    }
  }
  return result;
}
