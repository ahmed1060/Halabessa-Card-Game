import type { Card, MatchState } from "./match_engine.ts";
import { progressDeadline } from './match_progress.ts';

export type CommittedRoom = { state: MatchState; version: number; hands: Record<string, Card[]> };

/** Bounded metadata, not a capability or a replacement for the private ledger. */
export function withCommandReceipt(state: MatchState, commandId: string): MatchState {
  const prior = Array.isArray(state.recentCommandIds) ? state.recentCommandIds : [];
  return { ...state, recentCommandIds: [...prior.filter(id => typeof id === 'string' &&
    id !== commandId), commandId].slice(-32) };
}

/** A committed move is successful even if its realtime mirror needs repair. */
export async function commitAndDeliver<T>(commit: () => Promise<void>, deliver: () => Promise<T>) {
  await commit(); // Never publish uncommitted game state.
  try {
    return { snapshot: await deliver(), mirrorPending: false };
  } catch {
    return { snapshot: null, mirrorPending: true };
  }
}

export function publicMatchState(state: MatchState, version: number) {
  const publicState = { ...state } as Record<string, unknown>;
  const hands = state.handCards ?? {};
  publicState.handCounts = Object.fromEntries(Object.entries(hands)
    .map(([uid, cards]) => [uid, Array.isArray(cards) ? cards.length : 0]));
  publicState.serverVersion = version;
  const due = progressDeadline({ ...state, handCounts: publicState.handCounts });
  publicState.progressDueAt = due === null ? null : new Date(due).toISOString();
  for (const key of ["handCards", "deck", "secretDeck", "presence", "chat", "actions", "playerLastActive"]) {
    delete publicState[key];
  }
  return publicState;
}

export function participantSnapshot(room: CommittedRoom, uid: string) {
  return { state: publicMatchState({ ...room.state, handCards: room.hands }, room.version),
    hand: room.hands[uid] ?? [], version: room.version };
}

/** Atomic field updates preserve chat/presence writes occurring during delivery. */
export function matchMirrorUpdates(id: string, room: CommittedRoom,
  summarize: (state: Record<string, unknown>) => Record<string, unknown>) {
  if (!/^[A-Z]{3}[0-9]{5}$/.test(id)) throw new Error("invalid_room_id");
  const state = publicMatchState({ ...room.state, handCards: room.hands }, room.version);
  const updates: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(state)) {
    if (!/^[A-Za-z][A-Za-z0-9]*$/.test(key)) throw new Error("invalid_state_field");
    // Shown faces are disclosed to seated participants, not lobby browsers.
    // Keep the metadata in SQL and each authenticated single-revision view.
    if (key === 'cardFeatures') continue;
    updates[`matches/${id}/${key}`] = value;
  }
  updates[`matches/${id}/cardFeatures`] = null;
  updates[`matches/${id}/handCards`] = null;
  updates[`matches/${id}/deck`] = null;
  updates[`matchHands/${id}`] = room.hands;
  // Each private child is a complete, single-revision view. Never put these
  // under the publicly readable match node, or publish bot/departed hands.
  updates[`matchViews/${id}`] = Object.fromEntries((room.state.playerIds ?? [])
    .filter(uid => !uid.startsWith('bot_') && !uid.startsWith('waiting_'))
    .map(uid => {
      if (!/^[A-Za-z0-9:_-]{1,128}$/.test(uid)) throw new Error('invalid_player_uid');
      return [uid, { ...participantSnapshot(room, uid), recipientUid: uid }];
    }));
  updates[`matchSecrets/${id}`] = null;
  const { cardFeatures: _, ...lobbyState } = state;
  updates[`rooms/${id}`] = summarize(lobbyState);
  return updates;
}

/** The adapter must hold the SQL room lock until publish completes. Read the
 * latest committed row inside that lock, never an earlier request's response.
 * No session/advisory locks: this also works through transaction-mode poolers.
 */
export async function deliverLatestRoom(
  withLockedRoom: (publish: (room: CommittedRoom) => Promise<CommittedRoom>) => Promise<CommittedRoom>,
  publish: (room: CommittedRoom) => Promise<void>,
) {
  return withLockedRoom(async room => { await publish(room); return room; });
}
