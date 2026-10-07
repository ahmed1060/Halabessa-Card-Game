import {releasePlayer} from './turn_policy.ts';
import type {MatchState} from './match_engine.ts';

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
    if (typeof value === 'string') {
      if (value === uid) return anonymousId;
      // Tafweet's rank:controller references must retain their rank prefix.
      return value.endsWith(`:${uid}`) ? `${value.slice(0,-uid.length)}${anonymousId}` : value;
    }
    if (Array.isArray(value)) return value.map(scrub);
    if (!value || typeof value !== 'object') return value;
    const original = value as Record<string,unknown>;
    const attributed = ['uid','senderId','playerId','playedBy','actorUid','previousUid']
      .some(field => original[field] === uid);
    return Object.fromEntries(Object.entries(original).map(([key,entry]) => {
      if (attributed && ['displayName','senderName','playerName','name'].includes(key)) entry = 'Deleted player';
      if (attributed && ['avatarUrl','photoUrl','email'].includes(key)) entry = '';
      return [key === uid ? anonymousId : key,scrub(entry)];
    }));
  }
  const result = scrub(next) as MatchState;
  for (const field of ['playerNames','playerAvatars','playerSkins','playerEmojis','playerEmojiExpiresAt','playerLastActive','playerOnlineStatus']) {
    const map = result[field];
    if (map && typeof map === 'object' && !Array.isArray(map) && anonymousId in map) {
      delete (map as Record<string,unknown>)[anonymousId];
    }
  }
  return result;
}
