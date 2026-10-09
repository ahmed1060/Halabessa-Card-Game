import {deletionStages, type DeletionJob, type DeletionStage, type DeletionStore} from './account_deletion.ts';

// Supply a single admitted Postgres connection, never a shared global client.
export type DeletionQuery = (sql: string, parameters: unknown[]) => Promise<Record<string, unknown>[]>;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const hashPattern = /^[a-f0-9]{64}$/;
const columns = 'id::text, firebase_uid, completed_stages, status';
function job(row: Record<string, unknown> | undefined): DeletionJob {
  if (!row || typeof row.id !== 'string' || typeof row.firebase_uid !== 'string' ||
      !Array.isArray(row.completed_stages) || !['pending','complete'].includes(String(row.status))) {
    throw new Error('invalid_deletion_job');
  }
  const stages = row.completed_stages;
  if (stages.length > 6 || stages.some((stage,index) => stage !== deletionStages[index]) ||
      (row.status === 'complete' && stages.length !== 6)) throw new Error('invalid_deletion_job');
  return {id:row.id, uid:row.firebase_uid, completedStages:[...stages] as DeletionStage[], status:row.status as DeletionJob['status']};
}

/** The client generates AND durably saves a random receipt before submitting its
 * confirmed deletion. Only its SHA-256 digest is stored. This receipt supports
 * status/recovery after Firebase has disabled the user's identity. It is not a
 * Firebase token, never grants normal gameplay access, and must not be logged.
 */
export async function deletionReceiptHash(receipt: unknown) {
  if (typeof receipt !== 'string' || !hashPattern.test(receipt)) throw new Error('invalid_deletion_receipt');
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(receipt));
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2,'0')).join('');
}

export function createDeletionJobStore(query: DeletionQuery, receiptHash?: string): DeletionStore & {assertLease: (id: string) => void} {
  if (receiptHash !== undefined && !hashPattern.test(receiptHash)) throw new Error('invalid_deletion_receipt');
  let leasedId: string | null = null;
  function requireLease(id: string) {
    if (leasedId !== id) throw new Error('deletion_lease_required');
  }
  async function read(id: string) {
    if (!uuid.test(id)) throw new Error('invalid_deletion_job');
    return job((await query(`select ${columns} from halabessa.account_deletion_jobs where id=$1::uuid`, [id]))[0]);
  }
  return {
    assertLease: requireLease,
    async createOrGet(uid) {
      if (!receiptHash || !uid || uid.length > 128) throw new Error('invalid_deletion_receipt');
      await query('insert into halabessa.account_deletion_jobs (firebase_uid,receipt_hash) values ($1,$2) on conflict (firebase_uid) do nothing', [uid,receiptHash]);
      const rows = await query(`select ${columns} from halabessa.account_deletion_jobs where firebase_uid=$1 and receipt_hash=$2`, [uid,receiptHash]);
      if (!rows[0]) throw new Error('deletion_receipt_conflict');
      return job(rows[0]);
    },
    async withLease(id, work) {
      if (!uuid.test(id) || leasedId !== null) throw new Error('invalid_deletion_lease');
      await query('begin', []);
      try {
        // Transaction row locks work across Edge isolates and with transaction
        // pooling. Never use session-level advisory locks on a pooled connection.
        const rows = await query('select id from halabessa.account_deletion_jobs where id=$1::uuid for update nowait', [id]);
        if (!rows[0]) throw new Error('invalid_deletion_job');
        leasedId = id;
        const result = await work();
        await query('commit', []);
        return result;
      } catch (error) {
        await query('rollback', []);
        if (error && typeof error === 'object') {
          const candidate = error as {code?:unknown;fields?:{code?:unknown}};
          if ((candidate.code ?? candidate.fields?.code) === '55P03') throw new Error('deletion_worker_busy');
        }
        throw error;
      } finally { leasedId = null; }
    },
    read,
    async recordStage(id, stage) {
      requireLease(id);
      const count = deletionStages.indexOf(stage);
      if (count < 0) throw new Error('invalid_deletion_stage');
      const rows = await query(`update halabessa.account_deletion_jobs set completed_stages=array_append(completed_stages,$2::text), last_failed_stage=null, updated_at=now()
        where id=$1::uuid and status='pending' and cardinality(completed_stages)=$3 returning id`, [id,stage,count]);
      if (!rows[0]) throw new Error('invalid_deletion_stage');
    },
    async recordFailure(id, stage) {
      requireLease(id);
      if (!deletionStages.includes(stage)) throw new Error('invalid_deletion_stage');
      await query('update halabessa.account_deletion_jobs set last_failed_stage=$2,updated_at=now() where id=$1::uuid and status=\'pending\'', [id,stage]);
    },
    async recordProgress(id) {
      requireLease(id);
      // Ordinary bounded work is pending, not a cleanup failure. Rotating the
      // timestamp also prevents a large inventory from starving other jobs.
      await query("update halabessa.account_deletion_jobs set last_failed_stage=null,updated_at=now() where id=$1::uuid and status='pending'",[id]);
    },
    async markComplete(id) {
      requireLease(id);
      const rows = await query(`update halabessa.account_deletion_jobs set status='complete',completed_at=now(),last_failed_stage=null,updated_at=now()
        where id=$1::uuid and cardinality(completed_stages)=6 returning id`, [id]);
      if (!rows[0]) throw new Error('invalid_deletion_job');
    },
  };
}

// Receipt-authenticated status exposes no UID, email, stage error or secret.
export async function deletionStatus(query: DeletionQuery, id: unknown, receipt: unknown) {
  if (typeof id !== 'string' || !uuid.test(id)) throw new Error('invalid_deletion_receipt');
  const hash = await deletionReceiptHash(receipt);
  const row = (await query('select status from halabessa.account_deletion_jobs where id=$1::uuid and receipt_hash=$2', [id,hash]))[0];
  if (!row || !['pending','complete'].includes(String(row.status))) throw new Error('invalid_deletion_receipt');
  return {status:row.status as 'pending' | 'complete'};
}

// Recover acceptance even if its HTTP response was lost after the durable
// insert. The random receipt, not an email/UID, is the only lookup credential.
export async function recoverDeletion(query: DeletionQuery, receipt: unknown) {
  const hash = await deletionReceiptHash(receipt);
  const row = (await query('select id::text,status,apple_required,apple_revoked from halabessa.account_deletion_jobs where receipt_hash=$1', [hash]))[0];
  if (!row) return {status:'not_found' as const};
  if (typeof row.id !== 'string' || !uuid.test(row.id) || !['pending','complete'].includes(String(row.status))) {
    throw new Error('invalid_deletion_job');
  }
  return {id:row.id,status:row.apple_required===true && row.apple_revoked!==true
    ? 'needs_apple_authorization' as const : row.status as 'pending'|'complete'};
}
