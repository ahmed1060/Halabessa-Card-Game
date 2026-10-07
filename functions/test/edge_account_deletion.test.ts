import test from 'node:test';
import assert from 'node:assert/strict';
import { authorizeDeletion, beginDeletion, continueDeletion, deletionStages,
  type DeletionActor, type DeletionJob, type DeletionStore, type DeletionEffects } from '../../supabase/functions/halabessa-api/account_deletion.ts';
const now = 1791363600;
const actor: DeletionActor = {uid:'qa-only',email:null,admin:false,authTime:now,issuedAt:now,verifiedGuest:false};
const request = {confirmation:'DELETE MY ACCOUNT'};
const primary = 'owner@example.test';

test('only self deletion, explicit confirmation and recent auth are accepted', () => {
  assert.equal(authorizeDeletion(actor, request, primary, now), actor.uid);
  for (const changes of [{targetUid:'victim'}, {uid:'qa-only'}]) {
    assert.throws(() => authorizeDeletion(actor, {...request,...changes}, primary, now), /target_forbidden/);
  }
  assert.throws(() => authorizeDeletion(actor, {}, primary, now), /confirmation_required/);
  for (const authTime of [null, NaN, Infinity, now-301, now+6]) {
    assert.throws(() => authorizeDeletion({...actor,authTime}, request, primary, now), /recent_login/);
  }
  assert.throws(() => authorizeDeletion({...actor,authTime:now-1000,issuedAt:now}, request, primary, now), /recent_login/);
  assert.throws(() => authorizeDeletion({...actor,admin:true}, request, primary, now), /protected_account/);
  assert.throws(() => authorizeDeletion({...actor,email:primary.toUpperCase()}, request, primary, now), /protected_account/);
});
test('verified guests can confirm with a fresh token without replacing their UID', () => {
  assert.equal(authorizeDeletion({...actor,verifiedGuest:true,authTime:null}, request, primary, now), actor.uid);
  assert.throws(() => authorizeDeletion({...actor,verifiedGuest:true,issuedAt:now-61}, request, primary, now), /recent_login/);
});

function fixture() {
  const job: DeletionJob = {id:'private-job',uid:actor.uid,completedStages:[],status:'pending'};
  const calls: string[] = [];
  let failStage: string | null = null;
  let tail = Promise.resolve();
  const store: DeletionStore = {
    async createOrGet() { calls.push('persist-job'); return structuredClone(job); },
    async withLease(_id, work) {
      const previous=tail; let release!: () => void;
      tail=new Promise<void>(resolve => {release=resolve;});
      await previous;
      try { return await work(); } finally { release(); }
    },
    async read() { return structuredClone(job); },
    async recordStage(_id, stage) { job.completedStages.push(stage); },
    async recordFailure(_id, stage) { calls.push(`failed:${stage}`); },
    async markComplete() { job.status='complete'; },
  };
  const effects = Object.fromEntries(deletionStages.map(stage => [stage, async (uid: string) => {
    assert.equal(uid, actor.uid); calls.push(stage);
    if (stage===failStage) throw new Error('private-token-must-not-be-saved');
  }])) as DeletionEffects;
  return {job,calls,store,effects,setFailure(stage: string|null) {failStage=stage;}};
}
test('acceptance is durable before any destructive effect; bounded work resumes', async () => {
  const f=fixture();
  await beginDeletion(f.store, actor, request, primary, now);
  assert.deepEqual(f.calls,['persist-job']);
  assert.deepEqual(await continueDeletion(f.store,f.job.id,f.effects), {status:'pending'});
  assert.deepEqual(f.job.completedStages,deletionStages.slice(0,2));
  await continueDeletion(f.store,f.job.id,f.effects);
  assert.deepEqual(await continueDeletion(f.store,f.job.id,f.effects), {status:'complete'});
  assert.deepEqual(f.calls,['persist-job',...deletionStages]);
  await continueDeletion(f.store,f.job.id,f.effects);
  assert.equal(f.calls.length,7);
});
test('cleanup failure never deletes identity or reports completion; retry resumes at failure', async () => {
  const f=fixture(); f.setFailure('removeProfileAndReservations');
  assert.deepEqual(await continueDeletion(f.store,f.job.id,f.effects,6), {status:'pending'});
  assert.deepEqual(f.job.completedStages,deletionStages.slice(0,3));
  assert.equal(f.calls.includes('deleteIdentity'),false);
  assert.equal(f.calls.some(value=>value.includes('private-token')),false);
  f.setFailure(null);
  await continueDeletion(f.store,f.job.id,f.effects,6);
  assert.equal(f.job.status,'complete');
  assert.equal(f.calls.filter(value=>value==='blockSessions').length,1);
});
test('concurrent workers are serialized and identity cleanup runs once', async () => {
  const f=fixture();
  await Promise.all([continueDeletion(f.store,f.job.id,f.effects,6),continueDeletion(f.store,f.job.id,f.effects,6)]);
  assert.deepEqual(f.calls,deletionStages);
});
test('invalid stored stages cannot skip data cleanup or target a different job', async () => {
  const f=fixture(); f.job.completedStages=['deleteIdentity'];
  await assert.rejects(continueDeletion(f.store,f.job.id,f.effects,6),/invalid_deletion_job/);
  assert.equal(f.calls.length,0);
  f.job.completedStages=[];
  await assert.rejects(continueDeletion(f.store,'another-job',f.effects,6),/invalid_deletion_job/);
});
