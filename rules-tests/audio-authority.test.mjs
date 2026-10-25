// Real REST transactions against a loopback-only, isolated emulator project.
import {before,after,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc} from 'firebase/firestore';
import {audioSettingSlot,createAudioSettingsStore,updateAudioSetting} from '../supabase/functions/halabessa-api/audio_settings.ts';

const host=process.env.FIRESTORE_EMULATOR_HOST??'';
assert.match(host,/^(127\.0\.0\.1|localhost):\d+$/);
const project='demo-halabessa-audio-authority';
let environment;
before(async()=>{environment=await initializeTestEnvironment({projectId:project,firestore:{rules:await readFile(new URL('../firestore.rules',import.meta.url),'utf8')}});});
beforeEach(async()=>environment.clearFirestore());
after(async()=>environment?.cleanup());
function store() {
  return createAudioSettingsStore(project,async()=> 'owner',(url,init)=>{
    assert.ok(String(url).startsWith(`https://firestore.googleapis.com/v1/projects/${project}/`));
    return fetch(String(url).replace('https://firestore.googleapis.com',`http://${host}`),init);
  });
}
const ref=(db,id)=>doc(db,`settings/global/overrides/${id}`);
for(const [kind,assetKey] of [['sfx','sfx/capture.mp3'],['music','music/bg_music.mp3'],['room_music','music/room_music.mp3']]) {
  test(`server REST save/restore preserves committed data and unrelated settings: ${kind}`,async()=>{
    const slot=audioSettingSlot({kind,assetKey});const api=store();
    const db=environment.authenticatedContext('reader').firestore();
    await environment.withSecurityRulesDisabled(async context=>{
      const admin=context.firestore();
      await setDoc(doc(admin,'settings/global'),{defaultTurnTimer:15,defaultTargetScore:61});
      await setDoc(ref(admin,'other'),{url:'untouched'});
    });
    await api.replace(slot,'https://legacy.invalid/committed-A.wav');
    assert.equal(await api.copy(slot,true),true);
    await api.replace(slot,'https://legacy.invalid/committed-B.wav');
    assert.equal((await getDoc(ref(db,slot.id+'_backup'))).data().url,'https://legacy.invalid/committed-A.wav');
    assert.equal(await api.copy(slot,false),true);
    assert.equal((await getDoc(ref(db,slot.id))).data().url,'https://legacy.invalid/committed-A.wav');
    await api.restoreBundled(slot);
    assert.equal((await getDoc(ref(db,slot.id))).exists(),false);
    assert.equal((await getDoc(ref(db,slot.id+'_backup'))).data().url,'https://legacy.invalid/committed-A.wav');
    assert.deepEqual((await getDoc(doc(db,'settings/global'))).data(),{defaultTurnTimer:15,defaultTargetScore:61});
    assert.equal((await getDoc(ref(db,'other'))).data().url,'untouched');
  });
}
test('missing source never erases saved default; missing backup resets only active pointer',async()=>{
  const api=store(),slot=audioSettingSlot({kind:'music',assetKey:'music/bg_music.mp3'});
  const db=environment.authenticatedContext('reader').firestore();
  await environment.withSecurityRulesDisabled(context=>setDoc(ref(context.firestore(),'music_backup'),{url:'saved'}));
  assert.equal(await api.copy(slot,true),false);
  assert.equal((await getDoc(ref(db,'music_backup'))).data().url,'saved');
  const other=audioSettingSlot({kind:'room_music',assetKey:'music/room_music.mp3'});
  await api.replace(other,'custom');assert.equal(await api.copy(other,false),false);
  assert.equal((await getDoc(ref(db,'room_music'))).exists(),false);
});
test('ordinary admission failure reaches no REST mutation even with valid-looking payload',async()=>{
  let calls=0;
  const api=createAudioSettingsStore(project,async()=>{calls++;return 'owner';});
  await assert.rejects(updateAudioSetting({operation:'restoreBundled',kind:'music',assetKey:'music/bg_music.mp3'},
    {authorize:async()=>{throw new Error('admin_required');},store:api,storageUrl:'https://test.supabase.co'}),/admin_required/);
  assert.equal(calls,0);
});
