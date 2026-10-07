import test from 'node:test';
import assert from 'node:assert/strict';
import {createRealtimeDeletionDataStore} from '../../supabase/functions/halabessa-api/deletion_realtime_data.ts';
function fixture(handler:(url:URL,init:any)=>Response) {
  const calls:{url:URL,init:any}[]=[];
  const store=createRealtimeDeletionDataStore('https://qa.firebaseio.com',async()=>'server-only',async(url,init)=>{
    const parsed=new URL(String(url));calls.push({url:parsed,init});return handler(parsed,init);
  });
  return {store,calls};
}
test('own mirror/presence cleanup leaves the persistent block and all other users alone',async()=>{
  const {store,calls}=fixture(()=>Response.json(null));
  await store.block('alice');await store.removeOwnProfileAndPresence('alice');
  assert.equal(calls[0].url.pathname,'/accountDeletionBlocked/alice.json');assert.equal(calls[0].init.body,'true');
  assert.deepEqual(JSON.parse(calls[1].init.body),{'users/alice':null,'userPresence/alice':null,'userMatches/alice':null});
  assert.equal(calls[1].init.method,'PATCH');
  await assert.rejects(store.removeOwnProfileAndPresence('../bob'),/invalid_deletion_uid/);
  assert.equal(calls.length,2);
});
test('peer mirror social cleanup uses a per-field ETag and preserves unrelated edges',async()=>{
  const {store,calls}=fixture((_url,init)=>init.method==='GET'
    ?Response.json(['alice','carol'],{headers:{etag:'"read-version"'}}):Response.json(['carol']));
  await store.removePeerSocialEdges('alice','bob');
  const writes=calls.filter(c=>c.init.method==='PUT');assert.equal(writes.length,3);
  for(const write of writes) {
    assert.equal(write.init.headers['if-match'],'"read-version"');
    assert.deepEqual(JSON.parse(write.init.body),['carol']);
    assert.match(write.url.pathname,/^\/users\/bob\/(friends|pendingFriendRequests|sentFriendRequests)\.json$/);
  }
});
test('concurrent mirror changes cannot be overwritten; ETag conflict stays pending',async()=>{
  const {store,calls}=fixture((_url,init)=>init.method==='GET'
    ?Response.json(['alice','carol'],{headers:{etag:'"old"'}}):new Response('{}',{status:412}));
  await assert.rejects(store.removePeerSocialEdges('alice','bob'),/deletion_realtime_unavailable/);
  assert.equal(calls.length,2);
});
test('message cleanup deletes only authored messages across all four channels, not whole chats',async()=>{
  const {store,calls}=fixture((_url,init)=>Response.json(init.method==='GET'?{
    'message-1':{senderId:'alice',senderName:'Private',text:'private text'},
  }:null));
  assert.equal(await store.removeRoomMessages('alice','ABC12345'),true);
  const reads=calls.filter(c=>c.init.method==='GET');assert.equal(reads.length,4);
  for(const read of reads) {
    assert.equal(read.url.searchParams.get('orderBy'),'"senderId"');
    assert.equal(read.url.searchParams.get('equalTo'),'"alice"');
    assert.equal(read.url.searchParams.get('limitToFirst'),'40');
  }
  const updates=JSON.parse(calls.at(-1)!.init.body);
  assert.deepEqual(updates,{
    'matchChat/ABC12345/public/message-1':null,'matchChat/ABC12345/teamA/message-1':null,
    'matchChat/ABC12345/teamB/message-1':null,'matches/ABC12345/chat/message-1':null,
    'matchChat/ABC12345/rate/alice':null,'matches/ABC12345/presence/alice':null,
  });
});
test('a full message batch remains pending; malformed/other-sender results issue no deletion',async()=>{
  const full=fixture((_url,init)=>Response.json(init.method==='GET'
    ?Object.fromEntries(Array.from({length:40},(_,i)=>[`m${i}`,{senderId:'alice'}])):null));
  assert.equal(await full.store.removeRoomMessages('alice','ABC12345'),false);
  const wrong=fixture(()=>Response.json({m1:{senderId:'bob'}}));
  await assert.rejects(wrong.store.removeRoomMessages('alice','ABC12345'),/invalid_deletion_realtime_data/);
  assert.equal(wrong.calls.length,1);
  await assert.rejects(wrong.store.removeRoomMessages('alice','../../bob'),/invalid_deletion_room/);
  assert.equal(wrong.calls.length,1);
});
test('RTDB errors/missing ETags cannot count as successful cleanup',async()=>{
  const denied=fixture(()=>new Response('{}',{status:403}));
  await assert.rejects(denied.store.block('alice'),/deletion_realtime_unavailable/);
  const noEtag=fixture(()=>Response.json(['alice']));
  await assert.rejects(noEtag.store.removePeerSocialEdges('alice','bob'),/invalid_deletion_realtime_data/);
  assert.equal(noEtag.calls.length,1);
});
