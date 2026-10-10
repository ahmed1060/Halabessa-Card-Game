import { matchMirrorUpdates, type CommittedRoom } from './match_delivery.ts';

type Row = Record<string, unknown>;
export type MirrorRequest = (path: string, method?: string, body?: unknown, etag?: string) =>
  Promise<{status: number; data: unknown; etag: string | null}>;
const marker = '__halabessaDelivery';
const roots = ['matches', 'matchViews', 'matchHands', 'rooms'] as const;
const object = (value: unknown): Row => value && typeof value === 'object' && !Array.isArray(value)
  ? value as Row : {};

/** Firebase conditional PUT is the external fencing boundary. A SQL lease
 * alone cannot fence a timed-out HTTP write that later reaches Firebase.
 * Retry ONLY publication, never a game command. Never retry transport errors:
 * their completion is ambiguous; the durable SQL outbox owns recovery.
 */
async function fencedPut(request: MirrorRequest, path: string, version: number,
  next: Row, preserve: string[] = [], deleting = false) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const read = await request(path);
    if (read.status !== 200 || !read.etag) throw Error('match_mirror_read_failed');
    const current = object(read.data), fence = object(current[marker]);
    if (fence.deleted === true) {
      if (deleting) return;
      throw Error('room_deleted'); // Retained, non-personal tombstone reserves the short ID.
    }
    const observed = fence.version ?? current.serverVersion;
    if (observed !== undefined && (!Number.isSafeInteger(observed) || Number(observed) < 0)) {
      throw Error('invalid_mirror_version');
    }
    if (!deleting && observed !== undefined && Number(observed) > version) return;
    // Equal-version writes are deliberate: they repair partial delivery or a
    // removed private view without publishing an older state.
    const body: Row = {...next, [marker]: {version, ...(deleting ? {deleted: true} : {})}};
    for (const key of preserve) if (current[key] !== undefined) body[key] = current[key];
    const written = await request(path, 'PUT', body, read.etag);
    if (written.status >= 200 && written.status < 300) return;
    if (written.status !== 412) throw Error('match_mirror_failed');
    // Refetch the ETag AND version; never blindly resend an old body after 412.
  }
  throw Error('match_mirror_contended');
}

/** Each own-hand view remains atomic. Different roots may arrive separately;
 * clients already reconcile their revisions and recover via authenticated SQL.
 * All promises are settled before returning, even on failure, so a transaction
 * cannot release its lease while an unobserved sibling write is still running.
 */
export async function publishFencedMirror(request: MirrorRequest, id: string, room: CommittedRoom,
  summarize: (state: Row) => Row) {
  if (!Number.isSafeInteger(room.version) || room.version < 0) throw Error('invalid_mirror_version');
  if (room.state.playerIds?.includes(marker) || marker in room.hands) throw Error('reserved_player_uid');
  const updates = matchMirrorUpdates(id, room, summarize);
  const board: Row = {};
  for (const [path, value] of Object.entries(updates)) {
    const prefix = `matches/${id}/`;
    if (path.startsWith(prefix) && value !== null) board[path.slice(prefix.length)] = value;
  }
  const results = await Promise.allSettled(roots.map(root => fencedPut(request, `${root}/${id}`, room.version,
    root === 'matches' ? board : object(updates[`${root}/${id}`]),
    root === 'matches' ? ['chat', 'presence', 'playerLastActive', 'actions'] : [])));
  const failed = results.find((result): result is PromiseRejectedResult => result.status === 'rejected');
  if (failed) throw failed.reason;
  const cleared = await request(`matchSecrets/${id}`, 'PUT', null);
  if (cleared.status < 200 || cleared.status >= 300) throw Error('match_mirror_failed');
}

/** Do not remove these four tiny non-personal markers: removing them would
 * permit a delayed publisher to resurrect a deleted room. New room creation
 * already uses null_etag and retries a different ID on collision.
 */
export async function deleteFencedMirror(request: MirrorRequest, id: string) {
  if (!/^[A-Z]{3}[0-9]{5}$/.test(id)) throw Error('invalid_room_id');
  const results = await Promise.allSettled(roots.map(root =>
    fencedPut(request, `${root}/${id}`, 0, root === 'matches' ? {protocolVersion: 1} : {}, [], true)));
  const failed = results.find((result): result is PromiseRejectedResult => result.status === 'rejected');
  if (failed) throw failed.reason;
  const cleared = await request('', 'PATCH', {[`matchSecrets/${id}`]: null, [`matchChat/${id}`]: null});
  if (cleared.status < 200 || cleared.status >= 300) throw Error('room_delete_failed');
}
