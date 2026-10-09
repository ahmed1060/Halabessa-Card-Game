// Deletion's execution contract. Not an HTTP endpoint: production adapters
// must supply durable storage, a cross-isolate lease and idempotent cleanup.
export type DeletionActor = {
  uid: string;
  email: string | null;
  admin: boolean;
  authTime: number | null;
  issuedAt: number | null;
  // Must come from a current server-side identity lookup, not client metadata
  // or sign_in_provider alone (linked guests can retain that token claim).
  verifiedGuest: boolean;
};

export function authorizeDeletion(actor: DeletionActor, request: Record<string, unknown>,
  primaryAdminEmail: string, nowSeconds: number) {
  if (!actor.uid || !Number.isSafeInteger(nowSeconds)) throw new Error('unauthenticated');
  if ('targetUid' in request || 'uid' in request) throw new Error('deletion_target_forbidden');
  if (actor.admin || actor.email?.toLowerCase() === primaryAdminEmail.toLowerCase()) {
    throw new Error('protected_account');
  }
  if (request.confirmation !== 'DELETE MY ACCOUNT') throw new Error('deletion_confirmation_required');
  const fresh = (time: number | null, window: number) => time != null &&
    Number.isSafeInteger(time) && time <= nowSeconds + 5 && time >= nowSeconds - window;
  // Credentialed users need actual recent authentication, not just a refreshed
  // ID token. Confirmed guests have no credential to reauthenticate with.
  if (!(actor.verifiedGuest ? fresh(actor.issuedAt, 60) : fresh(actor.authTime, 300))) {
    throw new Error('requires_recent_login');
  }
  return actor.uid;
}

export const deletionStages = [
  'blockSessions', // SQL/Firestore/RTDB tombstones; disable/revoke identity
  'releaseAndAnonymizeRooms', // locked leave semantics + pending settlement
  'removeSocialAndMessages',
  'removeProfileAndReservations',
  'removeAvatarObjects',
  'deleteIdentity',
] as const;
export type DeletionStage = typeof deletionStages[number];
export type DeletionJob = {
  id: string;
  uid: string;
  completedStages: DeletionStage[];
  status: 'pending' | 'complete';
};
export interface DeletionStore {
  // Must be atomic/idempotent by uid; block ordinary account mutations as soon
  // as this durable job exists. A process-local mutex is insufficient.
  createOrGet(uid: string): Promise<DeletionJob>;
  // Authorized internal workers only. Receipt auth belongs in the HTTP layer.
  withLease<T>(id: string, work: () => Promise<T>): Promise<T>;
  read(id: string): Promise<DeletionJob>;
  recordStage(id: string, stage: DeletionStage): Promise<void>;
  recordFailure(id: string, stage: DeletionStage): Promise<void>;
  recordProgress?(id: string): Promise<void>;
  markComplete(id: string): Promise<void>;
}
export type DeletionEffects = Record<DeletionStage, (uid: string) => Promise<void>>;

function validateJob(job: DeletionJob, id: string) {
  if (job.id !== id || !job.uid || !['pending', 'complete'].includes(job.status)) {
    throw new Error('invalid_deletion_job');
  }
  // Refuse holes, duplicates or out-of-order stored stages. Do not let a damaged
  // record authorize identity deletion before data cleanup has completed.
  if (job.completedStages.length > deletionStages.length ||
      job.completedStages.some((stage, index) => stage !== deletionStages[index]) ||
      (job.status === 'complete' && job.completedStages.length !== deletionStages.length)) {
    throw new Error('invalid_deletion_job');
  }
}

export async function beginDeletion(store: DeletionStore, actor: DeletionActor,
  request: Record<string, unknown>, primaryAdminEmail: string, nowSeconds: number) {
  const uid = authorizeDeletion(actor, request, primaryAdminEmail, nowSeconds);
  const job = await store.createOrGet(uid);
  validateJob(job, job.id);
  if (job.uid !== uid) throw new Error('invalid_deletion_job');
  // No cleanup occurs here: durable acceptance must precede revocation.
  return job;
}

/** Run bounded work; a failed stage remains pending and resumes idempotently.
 * A timeout after an external effect but before recording it will repeat that
 * effect, so production adapters must treat already-removed data as success.
 */
export async function continueDeletion(store: DeletionStore, id: string,
  effects: DeletionEffects, maximumStages = 2): Promise<{status: 'pending' | 'complete'}> {
  if (!Number.isSafeInteger(maximumStages) || maximumStages < 1 || maximumStages > deletionStages.length) {
    throw new Error('invalid_deletion_batch');
  }
  return store.withLease(id, async () => {
    const job = await store.read(id);
    validateJob(job, id);
    if (job.status === 'complete') return {status: 'complete'};
    const stages = deletionStages.slice(job.completedStages.length,
      job.completedStages.length + maximumStages);
    for (const stage of stages) {
      try {
        await effects[stage](job.uid);
        await store.recordStage(id, stage);
      } catch (error) {
        // Persist stage only, not untrusted exception text/tokens/private data.
        if (error instanceof Error && error.message === 'deletion_more_data' && store.recordProgress) {
          await store.recordProgress(id);
        } else {
          await store.recordFailure(id, stage);
        }
        return {status: 'pending'};
      }
    }
    const latest = await store.read(id);
    validateJob(latest, id);
    if (latest.uid !== job.uid) throw new Error('invalid_deletion_job');
    if (latest.completedStages.length === deletionStages.length) {
      await store.markComplete(id);
      return {status: 'complete'};
    }
    return {status: 'pending'};
  });
}
