import test from 'node:test';
import assert from 'node:assert/strict';
import {createDeletionJobStore,deletionReceiptHash,deletionStatus,type DeletionQuery} from '../../supabase/functions/halabessa-api/deletion_job_store.ts';
import {continueDeletion,deletionStages,type DeletionEffects} from '../../supabase/functions/halabessa-api/account_deletion.ts';
const id='10000000-0000-4000-8000-000000000001';
const receipt='a'.repeat(64);
const hash=await deletionReceiptHash(receipt);
function fixture() {
  let row: any;
  let locked=false;
  const calls: {sql:string;args:unknown[]}[]=[];
  const query: DeletionQuery=async (sql,args) => {
    calls.push({sql,args});
    if (sql.startsWith('insert')) {row ??= {id,firebase_uid:args[0],receipt_hash:args[1],status:'pending',completed_stages:[]};return [];}
    if (sql.includes('for update nowait')) {
      if(locked)throw Object.assign(new Error('locked'),{code:'55P03'});
      locked=true;return row ? [{id}] : [];
    }
    if(sql==='commit'||sql==='rollback'){locked=false;return [];}
    if(sql.includes('set completed_stages')) {
      if(row.completed_stages.length!==args[2])return [];
      row.completed_stages.push(args[1]);return [{id}];
    }
    if(sql.includes("set status='complete'")) {
      if(row.completed_stages.length!==6)return [];
      row.status='complete';return [{id}];
    }
    if(sql.startsWith('update'))return [];
    if(sql.startsWith('select')&&sql.includes('receipt_hash=$2')) {
      const ownerMatches=sql.includes('firebase_uid=$1')?row?.firebase_uid===args[0]:row?.id===args[0];
      return ownerMatches&&row.receipt_hash===args[1]?[structuredClone(row)]:[];
    }
    if(sql.startsWith('select')&&sql.includes('where id=$1'))return row?.id===args[0]?[structuredClone(row)]:[];
    return [];
  };
  return {query,calls,get row(){return row;}};
}
test('receipt is hashed; invalid input is rejected before SQL', async()=>{
  assert.equal(hash.length,64);assert.notEqual(hash,receipt);
  for(const bad of [null,'a'.repeat(63),'Z'.repeat(64)])await assert.rejects(deletionReceiptHash(bad),/invalid_deletion_receipt/);
});
test('idempotent creation cannot rotate receipt or change target',async()=>{
  const f=fixture(),store=createDeletionJobStore(f.query,hash);
  const first=await store.createOrGet('qa-only');
  assert.deepEqual(await store.createOrGet('qa-only'),first);
  await assert.rejects(createDeletionJobStore(f.query,'b'.repeat(64)).createOrGet('qa-only'),/receipt_conflict/);
  assert.equal(f.calls.some(call=>JSON.stringify(call.args).includes(receipt)),false);
});
test('every cleanup stage is persisted under a database row lock',async()=>{
  const f=fixture(),store=createDeletionJobStore(f.query,hash);
  await store.createOrGet('qa-only');
  const ran:string[]=[];
  const effects=Object.fromEntries(deletionStages.map(stage=>[stage,async()=>{ran.push(stage);}])) as DeletionEffects;
  await continueDeletion(store,id,effects,2);
  assert.deepEqual(f.row.completed_stages,deletionStages.slice(0,2));
  await continueDeletion(store,id,effects,4);
  assert.equal(f.row.status,'complete');assert.deepEqual(ran,deletionStages);
  assert.equal(f.calls.filter(call=>call.sql.includes('for update nowait')).length,2);
  assert.equal(f.calls.filter(call=>call.sql==='commit').length,2);
});
test('stage writes and premature completion require the correct lease',async()=>{
  const f=fixture(),store=createDeletionJobStore(f.query,hash);await store.createOrGet('qa-only');
  await assert.rejects(store.recordStage(id,'blockSessions'),/lease_required/);
  await assert.rejects(store.withLease(id,()=>store.markComplete(id)),/invalid_deletion_job/);
  assert.equal(f.calls.at(-1)?.sql,'rollback');
});
test('database contention becomes a recoverable busy result',async()=>{
  const f=fixture(),first=createDeletionJobStore(f.query,hash),second=createDeletionJobStore(f.query,hash);
  await first.createOrGet('qa-only');
  await first.withLease(id,async()=>{
    await assert.rejects(second.withLease(id,async()=>{}),/deletion_worker_busy/);
  });
});
test('status needs the matching receipt and reveals only pending/complete',async()=>{
  const f=fixture();await createDeletionJobStore(f.query,hash).createOrGet('qa-only');
  assert.deepEqual(await deletionStatus(f.query,id,receipt),{status:'pending'});
  await assert.rejects(deletionStatus(f.query,id,'b'.repeat(64)),/invalid_deletion_receipt/);
  await assert.rejects(deletionStatus(f.query,'../other',receipt),/invalid_deletion_receipt/);
});
