import test from 'node:test';
import assert from 'node:assert/strict';
import { defaultPhrases, roomChatPolicy, canonicalChatMessage, publishRoomChat,
  readQuickPhrases, updateQuickPhrase, quickChatSuperadmin } from '../../supabase/functions/halabessa-api/table_chat.ts';
import type { MirrorRequest } from '../../supabase/functions/halabessa-api/mirror_fencing.ts';
const actor={uid:'alice',name:'Alice'}, config={revision:0,items:defaultPhrases};
function database() {
 const rows=new Map<string,unknown>(), versions=new Map<string,number>();
 let collide=false, ambiguous=false;
 const request:MirrorRequest=async(path,method='GET',body,etag)=>{
   const version=versions.get(path)??0;
   if(method==='GET') return {status:200,data:structuredClone(rows.get(path)??null),etag:'v'+version};
   if(collide){collide=false;return {status:412,data:null,etag:null};}
   if(etag!=='v'+version) return {status:412,data:null,etag:null};
   rows.set(path,structuredClone(body));versions.set(path,version+1);
   if(ambiguous){ambiguous=false;throw Error('network_timeout');}
   return {status:200,data:body,etag:'v'+(version+1)};
 };
 return {request,rows,collision(){collide=true;},timeoutAfterCommit(){ambiguous=true;}};
}
const directed=(people:string[])=>people.flatMap(a=>people.filter(b=>b!==a).map(b=>({owner_uid:a,friend_uid:b})));
test('typing requires every directed human friendship, excluding bots and waiting seats',()=>{
 const state={playerIds:['alice','bob','carol','bot_1'],phase:'playing',protocolVersion:1};
 const edges=directed(['alice','bob','carol']);
 assert.equal(roomChatPolicy(state,'alice',edges).canType,true);
 for(const missing of edges) assert.equal(roomChatPolicy(state,'alice',edges.filter(e=>e!==missing)).canType,false);
 assert.equal(roomChatPolicy({playerIds:['alice','bot_1','waiting_1'],phase:'playing',protocolVersion:1},'alice',[]).canType,false);
 assert.throws(()=>roomChatPolicy(state,'outsider',edges),/not_room_participant/);
 assert.throws(()=>roomChatPolicy({...state,phase:'closed'},'alice',edges),/not_room_participant/);
 assert.throws(()=>roomChatPolicy({...state,roomClosed:true},'alice',edges),/not_room_participant/);
 assert.throws(()=>roomChatPolicy({...state,protocolVersion:0},'alice',edges),/chat_unavailable/);
});
test('only current canonical presets bypass the typing lock; arbitrary flags/text cannot',()=>{
 const body={messageId:'message_1',presetId:'nice_play',locale:'ar',text:'forged',isQuickChat:true};
 const msg=canonicalChatMessage(body,actor,false,config,1000);
 assert.equal(msg.text,'لعبة حلوة!');assert.equal(msg.senderId,'alice');assert.equal(msg.timestamp,1000);
 assert.throws(()=>canonicalChatMessage({messageId:'m',text:'forged',isQuickChat:true},actor,false,config,1000),/typing_locked/);
 assert.throws(()=>canonicalChatMessage({...body,presetId:'deleted'},actor,false,config,1000),/invalid_chat_phrase/);
 assert.throws(()=>canonicalChatMessage({...body,channel:'teamA'},actor,true,config,1000),/invalid_chat_channel/);
 for(const text of ['', 'x'.repeat(61),'hello\nworld']) assert.throws(()=>
   canonicalChatMessage({messageId:'m',text},actor,true,config,1000),/invalid_chat_message/);
 assert.equal(canonicalChatMessage({messageId:'m',text:'  hello  '},actor,true,config,1000).text,'hello');
});
test('superadmin uses fresh account identity, not delegated admin or stale token identity',()=>{
 const account={uid:'alice',email:'owner@example.com',disabled:false,validSince:100,verifiedGuest:false,admin:false,providers:['password']};
 assert.equal(quickChatSuperadmin(account,101,'owner@example.com'),true);
 assert.equal(quickChatSuperadmin({...account,email:'delegate@example.com',admin:true},101,'owner@example.com'),false);
 assert.throws(()=>quickChatSuperadmin({...account,disabled:true},101,'owner@example.com'),/unauthenticated/);
 assert.throws(()=>quickChatSuperadmin(account,99,'owner@example.com'),/unauthenticated/);
});
test('phrase CRUD is revisioned and does not alter sent text; deleting the last phrase stays empty',async()=>{
 const db=database();assert.equal((await readQuickPhrases(db.request)).items.length,5);
 const saved=await updateQuickPhrase(db.request,{operation:'save',revision:0,presetId:'nice_play',phrase:{en:'Well played!',ar:'لعب جميل!'}});
 assert.equal(saved.revision,1);assert.equal(saved.items[1].en,'Well played!');
 await assert.rejects(updateQuickPhrase(db.request,{operation:'delete',revision:0,presetId:'gg'}),/config_conflict/);
 let current=saved;
 for(const phrase of [...saved.items]) current=await updateQuickPhrase(db.request,{operation:'delete',revision:current.revision,presetId:phrase.id});
 assert.deepEqual((await readQuickPhrases(db.request)).items,[]);
});
test('CAS accepts one concurrent sender, enforces rate, preserves historical private data, deduplicates same ID',async()=>{
 const db=database();db.rows.set('matchChat/ABC12345',{teamA:{old:{text:'never exposed'}}});
 const msg=canonicalChatMessage({messageId:'a',text:'hello'},actor,true,config,2000);
 db.collision();assert.equal((await publishRoomChat(db.request,'ABC12345',msg)).ok,true);
 await publishRoomChat(db.request,'ABC12345',msg);
 await assert.rejects(publishRoomChat(db.request,'ABC12345',{...msg,id:'b',timestamp:2500}),/rate_limited/);
 await assert.rejects(publishRoomChat(db.request,'ABC12345',{...msg,text:'changed'}),/message_conflict/);
 const other=canonicalChatMessage({messageId:'c',text:'hi'},{uid:'bob',name:'Bob'},true,config,2200);
 await publishRoomChat(db.request,'ABC12345',other);
 const stored=db.rows.get('matchChat/ABC12345') as any;
 assert.equal(Object.keys(stored.public).length,2);assert.equal(stored.teamA.old.text,'never exposed');
});
test('ambiguous writes recover only with the same ID and never duplicate a public message',async()=>{
 const db=database();const msg=canonicalChatMessage({messageId:'a',text:'hello'},actor,true,config,2000);
 db.timeoutAfterCommit();await assert.rejects(publishRoomChat(db.request,'ABC12345',msg),/network_timeout/);
 await publishRoomChat(db.request,'ABC12345',msg);
 assert.equal(Object.keys((db.rows.get('matchChat/ABC12345') as any).public).length,1);
});

test('two simultaneous sends by one player cannot bypass the shared rate CAS',async()=>{
 const db=database();const first=canonicalChatMessage({messageId:'first',text:'hello'},actor,true,config,2000);
 const result=await Promise.allSettled([publishRoomChat(db.request,'ABC12345',first),
   publishRoomChat(db.request,'ABC12345',{...first,id:'second'})]);
 assert.equal(result.filter(r=>r.status==='fulfilled').length,1);
 assert.equal(Object.keys((db.rows.get('matchChat/ABC12345') as any).public).length,1);
});
