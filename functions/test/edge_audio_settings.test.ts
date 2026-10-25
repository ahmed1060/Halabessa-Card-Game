import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { authorizeAudioSettings, audioSettingSlot, immutableAudioUrl, updateAudioSetting, createAudioSettingsStore } from '../../supabase/functions/halabessa-api/audio_settings.ts';

const storageUrl = 'https://audio-example.supabase.co';
const key = 'sfx/capture.mp3';
const slot = audioSettingSlot({kind:'sfx', assetKey:key});
const url = `${storageUrl}/storage/v1/object/public/game-assets/audio/sfx/sfx-capture-mp3/v2/750ddf38-2f4a-4dcf-bc7b-0a5870c67fec.wav`;
const base = 'projects/demo-halabessa-audio/databases/(default)/documents';
const active = `${base}/settings/global/overrides/sfx_sfx_capture.mp3`;
const fields = {url:{stringValue:'https://legacy.example/saved.wav'}, assetPath:{stringValue:key}, metadata:{stringValue:'keep'}};
function fixture() {
  const calls: any[] = [];
  const dependencies = {
    authorize: async () => {calls.push('authorize');}, storageUrl,
    fetch: async (path: any, init: any) => {calls.push({path,init});return new Response(null,{headers:{'content-type':'audio/wav','content-length':'30032'}});},
    store: {replace: async (...args: any[]) => {calls.push(['replace',...args]);},
      restoreBundled: async (...args: any[]) => {calls.push(['bundled',...args]);},
      copy: async (...args: any[]) => {calls.push(['copy',...args]);return true;}},
  };
  return {calls,dependencies};
}

test('real admission rejects missing/disabled/revoked users and uses fresh identity for admin role', async () => {
  const account = {uid:'player',email:'current@example.invalid',disabled:false,validSince:10,verifiedGuest:false,admin:false,providers:['password']};
  for(const value of [null,{...account,disabled:true},{...account,validSince:11}]) {
    let calls=0;
    await assert.rejects(authorizeAudioSettings({uid:'player',authTime:10},async()=>value,async()=>{calls++;return true;}),/unauthenticated/);
    assert.equal(calls,0);
  }
  let actor;
  await assert.rejects(authorizeAudioSettings({uid:'player',authTime:10},async()=>account,async value=>{actor=value;return false;}),/admin_required/);
  assert.deepEqual(actor,{uid:'player',email:'current@example.invalid'});
  await authorizeAudioSettings({uid:'player',authTime:10},async()=>account,async()=>true);
  await assert.rejects(authorizeAudioSettings({uid:'player',authTime:10},async()=>account,async()=>{throw new Error('unauthenticated');}),/unauthenticated/);
});

test('all 16 existing logical slots retain exact document identities', () => {
  const names=['capture','deal','play','pick','return','reveal','slam_0','slam_1','slam_2','shuffle','cut','win','lose','purchase'];
  for(const n of names)assert.equal(audioSettingSlot({kind:'sfx',assetKey:`sfx/${n}.mp3`}).id,`sfx_sfx_${n}.mp3`);
  assert.equal(audioSettingSlot({kind:'music',assetKey:'music/bg_music.mp3'}).id,'music');
  assert.equal(audioSettingSlot({kind:'room_music',assetKey:'music/room_music.mp3'}).id,'room_music');
  for(const input of [{kind:'sfx',assetKey:'../../users/me'},{kind:'music',assetKey:key},{kind:'sfx',assetKey:'sfx/new.mp3'},{kind:'room_music',assetKey:'music/bg_music.mp3'}])assert.throws(()=>audioSettingSlot(input),/invalid_audio_setting/);
});

test('auth/admin/deletion failures reach no Storage or Firestore operation', async () => {
  for(const error of ['unauthenticated','admin_required','account_guard_unavailable']) {
    const {calls,dependencies}=fixture();dependencies.authorize=async()=>{throw new Error(error);};
    await assert.rejects(updateAudioSetting({operation:'replace',kind:'sfx',assetKey:key,url},dependencies),new RegExp(error));
    assert.deepEqual(calls,[]);
  }
});

test('replacement validates same-slot immutable asset before a field-specific publish', async () => {
  const {calls,dependencies}=fixture();
  assert.deepEqual(await updateAudioSetting({operation:'replace',kind:'sfx',assetKey:key,url},dependencies),{ok:true});
  assert.equal(calls[0],'authorize');assert.equal(calls[1].init.method,'HEAD');assert.equal(calls[1].init.redirect,'error');
  assert.deepEqual(calls[2],['replace',slot,url]);
});

test('external/cross-slot/mutable/query/traversal URLs cannot be fetched or published', async () => {
  for(const bad of [url.replace(storageUrl,'https://attacker.example'),url.replace('sfx-capture-mp3','sfx-play-mp3'),url+'?x=1',url+'#x',url.replace('/v2/','/'),url.replace('750ddf38','%2e%2e%2f'),url.replace('https:','http:'),url.replace('.wav','.html')]) {
    const {calls,dependencies}=fixture();
    await assert.rejects(updateAudioSetting({operation:'replace',kind:'sfx',assetKey:key,url:bad},dependencies),/invalid_audio_setting/);
    assert.deepEqual(calls,['authorize']);
  }
  assert.equal(immutableAudioUrl(slot,url,storageUrl),url);
});

test('failed/mislabeled/empty/oversized assets never change current or saved setting', async () => {
  for(const response of [new Response(null,{status:404}),new Response(null,{headers:{'content-type':'text/html','content-length':'30032'}}),new Response(null,{headers:{'content-type':'audio/wav','content-length':'0'}}),new Response(null,{headers:{'content-type':'audio/wav','content-length':String(4*1024*1024+1)}})]) {
    const {calls,dependencies}=fixture();dependencies.fetch=async()=>response;
    await assert.rejects(updateAudioSetting({operation:'replace',kind:'sfx',assetKey:key,url},dependencies),/audio_asset_unavailable/);
    assert.deepEqual(calls,['authorize']);
  }
});

test('saved operations use committed server state, never supplied UI URL', async () => {
  for(const operation of ['saveDefault','restoreSaved','restoreBundled']) {
    const {calls,dependencies}=fixture();
    await updateAudioSetting({operation,kind:'sfx',assetKey:key},dependencies);
    assert.deepEqual(calls,operation==='restoreBundled'?['authorize',['bundled',slot]]:['authorize',['copy',slot,operation==='saveDefault']]);
    await assert.rejects(updateAudioSetting({operation,kind:'sfx',assetKey:key,url:'stale'},dependencies),/invalid_audio_setting/);
  }
  const {dependencies}=fixture();dependencies.store.copy=async()=>false;
  await assert.rejects(updateAudioSetting({operation:'saveDefault',kind:'sfx',assetKey:key},dependencies),/audio_override_missing/);
  assert.deepEqual(await updateAudioSetting({operation:'restoreSaved',kind:'sfx',assetKey:key},dependencies),{ok:true,copied:false});
});

function restFixture(options: {missing?:boolean; conflict?:boolean; deny?:boolean; ambiguous?:boolean}={}) {
  const calls: any[]=[];let commitCount=0;let transactionCount=0;
  const store=createAudioSettingsStore('demo-halabessa-audio',async()=> 'server-only-token',async(path:any,init:any)=>{
    const body=init.body?JSON.parse(init.body):undefined;calls.push({path,method:init.method,body,authorization:init.headers.Authorization});
    if(options.deny)return new Response(JSON.stringify({error:{status:'PERMISSION_DENIED'}}),{status:403});
    if(path.endsWith(':beginTransaction'))return Response.json({transaction:`transaction-${++transactionCount}`});
    if(path.endsWith(':batchGet'))return Response.json([options.missing?{missing:body.documents[0]}:{found:{name:body.documents[0],fields}}]);
    if(path.endsWith(':commit')) {
      commitCount++;
      if(options.ambiguous)throw new Error('network disconnected after dispatch');
      if(options.conflict&&commitCount===1)return Response.json({error:{status:'ABORTED'}},{status:409});
    }
    return Response.json({});
  });
  return {store,calls};
}

test('replace and bundled reset touch only the active canonical document', async()=>{
  const {store,calls}=restFixture();await store.replace(slot,url);await store.restoreBundled(slot);
  assert.deepEqual(calls[0].body.writes,[{update:{name:active,fields:{url:{stringValue:url},assetPath:{stringValue:key}}}}]);
  assert.deepEqual(calls[1].body.writes,[{delete:active}]);
  assert.ok(calls.every(c=>c.authorization==='Bearer server-only-token'));
  await assert.rejects(store.restoreBundled({...slot,id:'../users/admin'}),/invalid_audio_setting/);
  assert.equal(calls.length,2);
});

test('save and restore read source within transaction; preserve legacy URL and metadata', async()=>{
  for(const backup of [true,false]) {
    const {store,calls}=restFixture();assert.equal(await store.copy(slot,backup),true);
    assert.ok(calls[0].path.endsWith(':beginTransaction'));
    assert.ok(calls[1].path.endsWith(':batchGet'));
    assert.deepEqual(calls[1].body,{documents:[active+(backup?'':'_backup')],transaction:'transaction-1'});
    assert.deepEqual(calls[2].body,{writes:[{update:{name:active+(backup?'_backup':''),fields:{...fields,isBackup:{booleanValue:backup}}}}],transaction:'transaction-1'});
    assert.equal(calls.length,3);
  }
});

test('missing active cannot erase backup; missing saved resets only active', async()=>{
  for(const backup of [true,false]) {
    const {store,calls}=restFixture({missing:true});assert.equal(await store.copy(slot,backup),false);
    if(backup)assert.ok(calls[2].path.endsWith(':rollback'));
    else assert.deepEqual(calls[2].body.writes,[{delete:active}]);
    assert.ok(!calls.some(c=>c.body?.writes?.some((w:any)=>w.delete===active+'_backup')));
  }
});

test('only an explicit transaction conflict retries; ambiguous mutations never retry', async()=>{
  const conflict=restFixture({conflict:true});assert.equal(await conflict.store.copy(slot,true),true);
  assert.equal(conflict.calls.filter(c=>c.path.endsWith(':beginTransaction')).length,2);
  const ambiguous=restFixture({ambiguous:true});await assert.rejects(ambiguous.store.copy(slot,true),/audio_store_unavailable/);
  assert.equal(ambiguous.calls.filter(c=>c.path.endsWith(':commit')).length,1);
  assert.ok(ambiguous.calls.at(-1).path.endsWith(':rollback'));
  const denied=restFixture({deny:true});await assert.rejects(denied.store.replace(slot,url),/audio_store_unavailable/);
  assert.equal(denied.calls.length,1);
});

test('entrypoint retains verified JWT/admin/deletion/active identity and server-only store',()=>{
  const source=readFileSync(new URL('../../supabase/functions/halabessa-api/index.ts',import.meta.url),'utf8');
  const route=source.slice(source.indexOf("if (body.action === 'updateAudioSetting')"),source.indexOf('return await withDatabaseGuard<Client, Response>'));
  assert.ok(route.includes('withDatabaseGuard<Client, boolean>(runDatabase, checkDeletionGuard'));
  assert.ok(route.includes('from halabessa.account_deletion_jobs'));
  assert.ok(route.includes('authorizeAudioSettings(user'));
  assert.ok(route.includes('isAdmin(connection, actor)'));
  assert.ok(route.includes('createAudioSettingsStore(firebaseProject, firebaseAccessToken)'));
  assert.ok(source.indexOf('await timing.measure(\'jwt\', () => firebaseUser(request))')<source.indexOf("if (body.action === 'updateAudioSetting')"));
});
