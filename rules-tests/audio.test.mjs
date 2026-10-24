// Local Firestore emulator only. Never accepts a production host/project.
import {before,after,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,deleteDoc,runTransaction} from 'firebase/firestore';
assert.match(process.env.FIRESTORE_EMULATOR_HOST??'',/^(127\.0\.0\.1|localhost):\d+$/);
const rules=await readFile(new URL('../firestore.rules',import.meta.url),'utf8');
let environment;
before(async()=>{environment=await initializeTestEnvironment({projectId:'demo-halabessa-audio',firestore:{rules}});});
beforeEach(async()=>environment.clearFirestore());
after(async()=>environment?.cleanup());
const ref=(db,id)=>doc(db,'settings/global/overrides/'+id);
async function copy(db,sourceId,targetId,backup,deleteWhenMissing=false){
  return runTransaction(db,async transaction=>{
    const source=await transaction.get(ref(db,sourceId));const data=source.data();
    if(typeof data?.url!=='string'||!data.url){if(deleteWhenMissing)transaction.delete(ref(db,targetId));return false;}
    transaction.set(ref(db,targetId),{...data,isBackup:backup});return true;
  });
}
for(const [id,assetPath] of [['sfx_sfx_play.mp3','sfx/play.mp3'],['music','music/bg_music.mp3'],['room_music','music/room_music.mp3']]){
  test(`admin can replace, preserve saved audio, restore and reset ${id}`,async()=>{
    const db=environment.authenticatedContext('audio-admin',{admin:true}).firestore();
    const main=doc(db,'settings/global');await setDoc(main,{defaultTurnTimer:15,defaultTargetScore:61});
    await setDoc(ref(db,'other'),{url:'untouched'});
    const a='https://storage.invalid/audio/sfx/key/v2/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.wav';
    const b='https://storage.invalid/audio/sfx/key/v2/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb.wav';
    await assertSucceeds(setDoc(ref(db,id),{url:a,...(id.startsWith('sfx_')?{assetPath}:{})}));
    assert.equal(await copy(db,id,id+'_backup',true),true);
    await assertSucceeds(setDoc(ref(db,id),{url:b,...(id.startsWith('sfx_')?{assetPath}:{})}));
    assert.equal((await getDoc(ref(db,id+'_backup'))).data().url,a);
    assert.equal(await copy(db,id+'_backup',id,false,true),true);
    assert.equal((await getDoc(ref(db,id))).data().url,a);
    await assertSucceeds(deleteDoc(ref(db,id)));
    assert.equal((await getDoc(ref(db,id))).exists(),false);
    assert.equal((await getDoc(ref(db,id+'_backup'))).data().url,a);
    assert.deepEqual((await getDoc(main)).data(),{defaultTurnTimer:15,defaultTargetScore:61});
    assert.equal((await getDoc(ref(db,'other'))).data().url,'untouched');
  });
}
test('ordinary/anonymous clients cannot upload override pointers, mark defaults, or reset',async()=>{
  const admin=environment.authenticatedContext('admin',{admin:true}).firestore();
  await setDoc(ref(admin,'music'),{url:'https://storage.invalid/current.wav'});
  for(const db of [environment.authenticatedContext('ordinary').firestore(),environment.unauthenticatedContext().firestore()]){
    await assertFails(setDoc(ref(db,'music'),{url:'https://attacker.invalid/replace.wav'}));
    await assertFails(copy(db,'music','music_backup',true));
    await assertFails(deleteDoc(ref(db,'music')));
  }
  assert.equal((await getDoc(ref(admin,'music'))).data().url,'https://storage.invalid/current.wav');
});
test('deleted accounts cannot use a still-valid admin claim',async()=>{
  await environment.withSecurityRulesDisabled(async context=>setDoc(doc(context.firestore(),'accountDeletionBlocked/blocked-admin'),{blocked:true}));
  const blocked=environment.authenticatedContext('blocked-admin',{admin:true}).firestore();
  await assertFails(setDoc(ref(blocked,'music'),{url:'not-allowed'}));
});
test('missing backup clears only the chosen pointer, retaining unrelated settings',async()=>{
  const db=environment.authenticatedContext('admin',{admin:true}).firestore();
  await setDoc(ref(db,'music'),{url:'custom'});await setDoc(ref(db,'room_music'),{url:'keep'});
  assert.equal(await copy(db,'music_backup','music',false,true),false);
  assert.equal((await getDoc(ref(db,'music'))).exists(),false);
  assert.equal((await getDoc(ref(db,'room_music'))).data().url,'keep');
});
