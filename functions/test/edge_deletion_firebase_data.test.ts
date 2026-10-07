import test from 'node:test';
import assert from 'node:assert/strict';
import {createFirebaseDeletionDataStore} from '../../supabase/functions/halabessa-api/deletion_firebase_data.ts';
const base='projects/qa-project/databases/(default)/documents';
const doc=(collection: string,id: string,fields: any)=>({name:`${base}/${collection}/${id}`,updateTime:'2026-10-07T00:00:00Z',fields});
function fixture(handler: (url: string,body: any)=>Response) {
  const calls: {url: string,body: any}[]=[];
  const store=createFirebaseDeletionDataStore('qa-project',async()=>'server-only',async(url,init)=>{
    const body=init?.body ? JSON.parse(String(init.body)) : null;
    assert.equal((init?.headers as any).Authorization,'Bearer server-only');
    calls.push({url:String(url),body});return handler(String(url),body);
  });
  return {store,calls};
}
test('deletion block is persistent, scoped to only the verified UID',async()=>{
  const {store,calls}=fixture(()=>Response.json({}));
  await store.block('alice');
  assert.deepEqual(calls[0].body.writes,[{update:{name:`${base}/accountDeletionBlocked/alice`,fields:{blocked:{booleanValue:true}}}}]);
  await assert.rejects(store.block('../bob'),/invalid_deletion_uid/);
  assert.equal(calls.length,1);
});
test('social cleanup removes only UID associations and preserves all unrelated peer fields',async()=>{
  const {store,calls}=fixture((url,body)=>{
    if (url.endsWith(':runQuery')) {
      const field=body.structuredQuery.where.fieldFilter.field.fieldPath;
      return Response.json([{document:doc('users','bob',{[field]:{arrayValue:{values:[{stringValue:'alice'},{stringValue:'carol'}]}},coins:{integerValue:'900'}})}]);
    }
    return Response.json({});
  });
  await store.removeSocialEdges('alice');
  const writes=calls.filter(c=>c.url.endsWith(':commit')).flatMap(c=>c.body.writes);
  assert.equal(writes.length,3);
  for (const write of writes) {
    assert.equal(write.delete,undefined);assert.equal(write.update,undefined);
    assert.equal(write.transform.document,`${base}/users/bob`);
    assert.deepEqual(write.transform.fieldTransforms[0].removeAllFromArray,{values:[{stringValue:'alice'}]});
    assert.equal(write.currentDocument.updateTime,'2026-10-07T00:00:00Z');
  }
  assert.equal(JSON.stringify(writes).includes('coins'),false);
});
test('bounded social cleanup stays pending when more rows may remain',async()=>{
  const {store,calls}=fixture(url=>Response.json(url.endsWith(':runQuery')
    ? Array.from({length:40},(_,i)=>({document:doc('users',`peer${i}`,{friends:{arrayValue:{values:[{stringValue:'alice'}]}}})})) : {}));
  await assert.rejects(store.removeSocialEdges('alice'),/deletion_more_data/);
  assert.equal(calls.filter(c=>c.url.endsWith(':commit'))[0].body.writes.length,40);
});
test('profile cleanup conditionally removes only owned reservations, then the owned profile',async()=>{
  const {store,calls}=fixture(url=>Response.json(url.endsWith(':runQuery')
    ? [{document:doc('usernames','alice-name',{uid:{stringValue:'alice'}})}]
    : url.endsWith('/users/alice') ? doc('users','alice',{coins:{integerValue:'123'}}) : {}));
  await store.removeProfileAndReservations('alice');
  assert.deepEqual(calls.filter(c=>c.url.endsWith(':commit')).flatMap(c=>c.body.writes),[
    {delete:`${base}/usernames/alice-name`,currentDocument:{updateTime:'2026-10-07T00:00:00Z'}},
    {delete:`${base}/users/alice`,currentDocument:{updateTime:'2026-10-07T00:00:00Z'}},
  ]);
});
test('absence is idempotent but denials, changed ownership and malformed documents fail closed',async()=>{
  const absent=fixture(url=>url.endsWith(':runQuery')?Response.json([]):new Response('{}',{status:404}));
  await absent.store.removeProfileAndReservations('alice');
  assert.equal(absent.calls.some(c=>c.url.endsWith(':commit')),false);
  const denied=fixture(()=>new Response('{}',{status:403}));
  await assert.rejects(denied.store.block('alice'),/deletion_data_unavailable/);
  const wrongOwner=fixture(()=>Response.json([{document:doc('usernames','bob',{uid:{stringValue:'bob'}})}]));
  await assert.rejects(wrongOwner.store.removeProfileAndReservations('alice'),/invalid_deletion_document/);
  assert.equal(wrongOwner.calls.length,1);
  const wrongPath=fixture(()=>Response.json([{document:doc('users','alice',{uid:{stringValue:'alice'}})}]));
  await assert.rejects(wrongPath.store.removeProfileAndReservations('alice'),/invalid_deletion_document/);
  const missingTime=fixture(()=>Response.json([{document:{name:`${base}/usernames/old`,fields:{uid:{stringValue:'alice'}}}}]));
  await assert.rejects(missingTime.store.removeProfileAndReservations('alice'),/invalid_deletion_document/);
});
test('a Firestore precondition conflict remains pending and cannot remove a newly reassigned username',async()=>{
  const {store,calls}=fixture(url=>url.endsWith(':runQuery')
    ? Response.json([{document:doc('usernames','shared',{uid:{stringValue:'alice'}})}])
    : new Response('{}',{status:409}));
  await assert.rejects(store.removeProfileAndReservations('alice'),/deletion_data_unavailable/);
  assert.equal(calls.length,2); // Never proceeds to profile deletion.
});
