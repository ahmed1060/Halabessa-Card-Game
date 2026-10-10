import type { Card, MatchState } from './match_engine.ts';
import type { CommittedRoom } from './match_delivery.ts';

export type PublicationQuery = (sql: string, args: unknown[]) => Promise<Record<string, unknown>[]>;
export function earlyAckEnabled(config: Record<string, unknown> | undefined, id: string) {
  return /^[A-Z]{3}[0-9]{5}$/.test(id) &&
    (config?.async_ack_enabled === true || config?.canary_room_id === id);
}
export async function publicationLease(query: PublicationQuery, id: string, wait = false) {
  if (!/^[A-Z]{3}[0-9]{5}$/.test(id)) throw new Error('invalid_room_id');
  // Transaction-scoped only: pooled sessions must never retain advisory locks.
  // Gameplay writers do not acquire this lease or touch a mutable lease row.
  const rows = await query(`select ${wait ? 'pg_advisory_xact_lock' : 'pg_try_advisory_xact_lock'}(hashtextextended($1,0)) as acquired`,
    [`halabessa-publication:${id}`]);
  return wait || rows[0]?.acquired === true;
}

/** Serialize publishers, not game commands. Read board+hands in one MVCC
 * statement after acquiring the lease; never publish an earlier HTTP response.
 * Keep game row locks during the initial compatible rollout until early ack
 * is enabled after live QA. All publishing/deletion adapters share the lease.
 */
export async function publishRoom(query: PublicationQuery, id: string,
  publish: (room: CommittedRoom) => Promise<void>, lockGameRows = true): Promise<CommittedRoom | null> {
  await query('begin', []);
  try {
    if (!await publicationLease(query, id)) {
      await query('rollback', []);
      return null; // Another publisher owns delivery; its queue is still durable.
    }
    const rows = await query(`select r.state,r.version::text as version,s.hands
      from halabessa.rooms r join halabessa.room_secrets s on s.room_id=r.room_id
      where r.room_id=$1${lockGameRows ? ' for update of r,s' : ''}`, [id]);
    const row = rows[0];
    if (!row) throw new Error('room_not_found');
    const version = Number(row.version);
    if (!row.state || typeof row.state !== 'object' || Array.isArray(row.state) ||
        (row.state as MatchState).protocolVersion !== 1 ||
        !Number.isSafeInteger(version) || version < 0 ||
        !row.hands || typeof row.hands !== 'object' || Array.isArray(row.hands)) {
      throw new Error('invalid_publication_snapshot');
    }
    const room = {state: row.state as MatchState, version, hands: row.hands as Record<string, Card[]>};
    await publish(room);
    // Commits after our SELECT have higher versions and retain their intents.
    await query('delete from halabessa.room_publications where room_id=$1 and version<=$2', [id, version]);
    await query('commit', []);
    return room;
  } catch (error) {
    await query('rollback', []);
    throw error; // Failure cannot erase a durable publication intent.
  }
}

export async function retryPublicationLater(query: PublicationQuery, id: string) {
  if (!/^[A-Z]{3}[0-9]{5}$/.test(id)) throw new Error('invalid_room_id');
  await query(`update halabessa.room_publications set attempts=attempts+1,
    next_attempt_at=now()+least(60,power(2,least(attempts,5))) * interval '1 second'
    where room_id=$1`, [id]);
}

/** Only call after SQL commits its state AND publication intent. Scheduling
 * failure or runtime termination leaves work for the server-only retry worker.
 */
export async function commitAndQueue(commit: () => Promise<void>, schedule: () => void) {
  await commit();
  try { schedule(); } catch { /* Durable queue is the fallback, not the runtime. */ }
  return {snapshot: null, mirrorPending: true};
}
