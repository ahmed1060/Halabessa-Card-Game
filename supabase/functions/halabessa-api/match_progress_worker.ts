import { advanceMatch } from './match_lifecycle.ts';
import type { Card, MatchState } from './match_engine.ts';
import { publicMatchState } from './match_delivery.ts';
import { progressDeadline } from './match_progress.ts';
import type { PublicationQuery, PublicationRunner } from './room_publication.ts';

export class ProgressRevisionFailure extends Error {
  readonly version: number;
  constructor(version: number, cause: unknown) {
    super('progress_revision_failed', { cause });
    this.version = version;
  }
}

export type ProgressTiming = {
  event: 'halabessa-progress-timing';
  transition: 'bot_play' | 'forced_card' | 'capture_completion' | 'human_timeout' | 'phase_progress';
  due_lag_ms: number; transaction_ms: number; engine_ms: number;
};

/** Lock rooms before jobs, just as gameplay writers do. Never sleep/publish here. */
export async function advanceScheduledRoom(query: PublicationQuery, id: string, now = Date.now,
  observe?: (record: ProgressTiming) => void, nextDeadline?: (due: number | null) => void) {
  if (!/^[A-Z]{3}[0-9]{5}$/.test(id)) throw Error('invalid_room_id');
  const transactionStart = performance.now();
  await query('begin', []);
  let failedVersion: number | undefined;
  try {
    const rows = await query(`select r.state,r.version::text as version,s.hands,s.deck,
      p.version::text as queued_version,p.due_at
      from halabessa.rooms r join halabessa.room_secrets s on s.room_id=r.room_id
      join halabessa.room_progress_jobs p on p.room_id=r.room_id
      join halabessa.publication_worker_config c on c.singleton=true
      where r.room_id=$1 and (c.progress_enabled or c.progress_canary_room_id=r.room_id)
      and p.next_attempt_at<=now()
      for update of r,s skip locked`, [id]);
    const row = rows[0];
    if (!row) { await query('rollback', []); return false; }
    const version = Number(row.version), queued = Number(row.queued_version);
    if (!Number.isSafeInteger(version) || version < 0 || version !== queued) throw Error('invalid_progress_revision');
    failedVersion = version;
    const state: MatchState = { ...(row.state as MatchState), handCards: row.hands as Record<string, Card[]> };
    const due = progressDeadline(state), time = now();
    if (due === null) {
      await query('delete from halabessa.room_progress_jobs where room_id=$1 and version=$2', [id, version]);
      await query('commit', []); return false;
    }
    if (time < due) { await query('rollback', []); return false; }
    const active = state.playerIds?.[Number(state.currentTurnIndex)];
    const category: ProgressTiming['transition'] = state.phase === 'capturing' ? 'capture_completion' :
      state.phase !== 'playing' ? 'phase_progress' :
      active && state.handCards?.[active]?.length === 1 ? 'forced_card' :
      active?.startsWith('bot_') ? 'bot_play' : 'human_timeout';
    const engineStart = performance.now();
    const transition = advanceMatch(state, row.deck as Card[] ?? [], time);
    const engineMs = performance.now() - engineStart;
    const publicState = publicMatchState({ ...transition.state, serverProgressManaged: true }, version + 1);
    await query(`update halabessa.rooms set state=$2::jsonb,version=$3,
      expires_at=$4::timestamptz,updated_at=now() where room_id=$1`,
    [id, JSON.stringify(publicState), version + 1, publicState.expireAt ?? null]);
    await query('update halabessa.room_secrets set hands=$2::jsonb,deck=$3::jsonb where room_id=$1',
      [id, JSON.stringify(transition.state.handCards ?? {}), JSON.stringify(transition.deck)]);
    // Both next deadline and publication intent are inserted by room triggers.
    await query('commit', []);
    // A hint from our own committed transition avoids reopening a connection
    // solely to read its job. The next locked execution still revalidates it.
    nextDeadline?.(progressDeadline(transition.state));
    try { observe?.({event: 'halabessa-progress-timing', transition: category,
      due_lag_ms: Math.max(0, now() - (due === 0 ? time : due)), transaction_ms: Math.round(performance.now() - transactionStart),
      engine_ms: Math.round(engineMs)}); } catch { /* Diagnostics never change accepted gameplay. */ }
    return true;
  } catch (error) {
    await query('rollback', []);
    if (failedVersion !== undefined) throw new ProgressRevisionFailure(failedVersion, error);
    throw error;
  }
}

/** Short automatic chains only. Durable jobs survive loss of this runtime. */
export async function runRoomProgress(run: PublicationRunner, id: string,
  publish: () => Promise<void>, options: {
    now?: () => number; elapsed?: () => number; sleep?: (ms: number) => Promise<void>;
    budgetMs?: number; maxSteps?: number;
    observe?: (record: ProgressTiming) => void;
  } = {}) {
  const now = options.now ?? Date.now, elapsed = options.elapsed ?? (() => performance.now());
  const sleep = options.sleep ?? (ms => new Promise(resolve => setTimeout(resolve, ms)));
  const started = elapsed(), budget = Math.min(options.budgetMs ?? 20000, 20000);
  let advanced = 0;
  let committedDeadline: number | null | undefined;
  for (let pass = 0; pass < Math.min(options.maxSteps ?? 16, 16); pass++) {
    let due = committedDeadline;
    if (due === undefined) {
      const jobs = await run(query => query(`select p.due_at from halabessa.room_progress_jobs p
      join halabessa.publication_worker_config c on c.singleton=true
      where p.room_id=$1 and (c.progress_enabled or c.progress_canary_room_id=p.room_id)
      and p.next_attempt_at<=now()`, [id]));
      if (!jobs[0]) break;
      const raw = jobs[0].due_at;
      due = raw instanceof Date ? raw.getTime() : Date.parse(String(raw));
    }
    if (due === null) break;
    if (!Number.isFinite(due)) throw Error('invalid_progress_deadline');
    const wait = Math.max(0, due - now());
    if (elapsed() - started + wait >= budget) break;
    if (wait > 0) await sleep(wait); // No socket/lock is retained by run().
    if (elapsed() - started >= budget) break;
    if (!await run(query => advanceScheduledRoom(query, id, now, options.observe,
      next => { committedDeadline = next; }))) break;
    advanced++;
    await publish(); // External version fencing; no room locks across delivery.
  }
  return advanced;
}
