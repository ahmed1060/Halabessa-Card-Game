import test from 'node:test';
import assert from 'node:assert/strict';
import {createDeletionAvatarStore} from '../../supabase/functions/halabessa-api/deletion_avatars.ts';
test('avatar cleanup removes all six historically allowed owned variants, never shared assets',async()=>{
  const calls: any[]=[];
  const store=createDeletionAvatarStore('https://qa.supabase.co','server-only',async(url,init)=>{
    calls.push({url:String(url),init});return Response.json([]);
  });
  await store.remove('alice');await store.remove('alice'); // Missing objects stay idempotent.
  assert.equal(calls.length,2);
  assert.equal(calls[0].url,'https://qa.supabase.co/storage/v1/object/game-assets');
  assert.equal(calls[0].init.method,'DELETE');
  assert.deepEqual(JSON.parse(calls[0].init.body),{prefixes:['avatars/alice/profile.jpg','avatars/alice/profile.png','avatars/alice/profile.webp',
    'avatars/alice/profile.mp3','avatars/alice/profile.wav','avatars/alice/profile.m4a']});
  assert.equal(calls[0].init.headers.apikey,'server-only');
});
test('ambiguous legacy owner paths and traversal never issue a deletion',async()=>{
  let calls=0;
  const store=createDeletionAvatarStore('https://qa.supabase.co','server-only',async()=>{calls++;return Response.json([]);});
  for (const uid of ['../bob','a:b','a'.repeat(81),'','avatars/bob']) {
    await assert.rejects(store.remove(uid),/ambiguous_avatar_owner/);
  }
  assert.equal(calls,0);
});
test('storage outage, denial, bucket absence and malformed success all stay pending',async()=>{
  for (const response of [new Response('{}',{status:403}),new Response('{}',{status:404}),new Response('{}',{status:503}),Response.json({error:'malformed'})]) {
    const store=createDeletionAvatarStore('https://qa.supabase.co','server-only',async()=>response);
    await assert.rejects(store.remove('alice'),/deletion_storage_unavailable/);
  }
});
