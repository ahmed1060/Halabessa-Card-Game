import test from 'node:test';
import assert from 'node:assert/strict';
import {createDeletionRoomStore} from '../../supabase/functions/halabessa-api/deletion_rooms.ts';
const jobId='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
function fixture(options: {owner?:string;pending?:boolean;legacy?:boolean;publishFailure?:boolean;allBots?:boolean}={}) {
  let leased=true,stages=['blockSessions'],outbox: boolean|null=null;
  let state:any={protocolVersion:options.legacy?0:1,serverVersion:4,phase:'playing',
    playerIds:['alice',options.allBots?'bot_2':'bob','bot_3','bot_4'],
    players:{alice:true,bob:true,bot_3:true,bot_4:true},playerNames:{alice:'Alice',bob:'Bob'},
    currentTurnIndex:0,teamAScore:7,teamBScore:5,settlementPending:options.pending??false,
    rewardRoster:['alice','bob','bot_3','bot_4'],captures:[{playedBy:'alice',playerName:'Alice'}]};
  let hands:any={alice:[{rank:'ace',suit:'hearts'}],bob:[{rank:'king',suit:'clubs'}]};
  let owner=options.owner??'alice',version=4;
  const calls:string[]=[],publications:any[]=[];
  let failure=options.publishFailure??false;
  const query=async(sql:string,p:unknown[])=>{
    calls.push(sql);
    if(sql.startsWith('select firebase_uid,completed_stages'))return [{firebase_uid:'alice',status:'pending',completed_stages:stages}];
    if(sql.startsWith('select room_id from halabessa.account_deletion_rooms'))return outbox===false?[{room_id:'ABC12345'}]:[];
    if(sql.startsWith('select r.room_id'))return outbox===null?[{room_id:'ABC12345',owner_uid:owner,state,version:String(version),created_at:'1791350000'}]:[];
    if(sql.startsWith('select room_id,state'))return [{room_id:'ABC12345',state,version:String(version)}];
    if(sql.startsWith('select hands'))return [{hands}];
    if(sql.startsWith('select p.firebase_uid'))return options.allBots?[]:[{firebase_uid:'bob'}];
    if(sql.startsWith('select profile,email'))return [{profile:{systemDeletionOwner:true},email:null}];
    if(sql.startsWith('update halabessa.rooms')){owner=String(p[1]);state=JSON.parse(String(p[2]));version=Number(p[3]);}
    if(sql.startsWith('update halabessa.room_secrets'))hands=JSON.parse(String(p[1]));
    if(sql.startsWith('insert into halabessa.account_deletion_rooms'))outbox=sql.includes(',true)');
    if(sql.startsWith('update halabessa.account_deletion_rooms'))outbox=true;
    return [];
  };
  let settleCount=0;
  const store=createDeletionRoomStore(query,()=>{if(!leased)throw new Error('deletion_lease_required');},
    async(s,at)=>{settleCount++;assert.equal(s.rewardRoster?.[0],'alice');assert.equal(at,'1791350000');return 'b'.repeat(64);},
    async(id,room)=>{if(failure)throw new Error('transport_failed');publications.push({id,room});});
  return {store,calls,publications,get state(){return state;},get owner(){return owner;},
    get hands(){return hands;},get settleCount(){return settleCount;},get outbox(){return outbox;},
    failPublish:(v:boolean)=>{failure=v;},setLease:(v:boolean)=>{leased=v;},setStages:(v:string[])=>{stages=v;}};
}
test('room change and pending outbox precede publication; retry publishes current committed state',async()=>{
  const f=fixture();
  assert.equal(await f.store.advance(jobId,'alice'),false);
  assert.equal(f.publications.length,0);assert.equal(f.outbox,false);
  assert.equal(f.owner,'bob');assert.equal(f.state.teamAScore,7);assert.equal(f.state.teamBScore,5);
  assert.equal(f.state.playerIds[1],'bob');assert.deepEqual(f.hands.bob,[{rank:'king',suit:'clubs'}]);
  assert.deepEqual(f.hands[f.state.playerIds[0]],[{rank:'ace',suit:'hearts'}]);
  assert.equal(JSON.stringify(f.state).includes('alice'),false);
  assert.equal(f.state.serverVersion,5);
  // A newer normal command can commit between prepare and delivery. Never use
  // the old prepared snapshot for the eventual mirror.
  f.state.teamBScore=9;
  assert.equal(await f.store.advance(jobId,'alice'),false);
  assert.equal(f.publications[0].room.state.teamBScore,9);
  const lease=f.calls.findIndex(c=>c.includes('pg_advisory_xact_lock'));
  const roomLock=f.calls.findIndex(c=>c.startsWith('select room_id,state'));
  assert.ok(lease>=0 && lease<roomLock,'publication lease must precede the room lock');
  assert.equal(f.outbox,true);assert.equal(await f.store.advance(jobId,'alice'),true);
  assert.equal(f.calls.filter(c=>c.startsWith('update halabessa.rooms')).length,1);
});
test('mirror transport failure leaves durable delivery pending without repeating bot takeover',async()=>{
  const f=fixture({publishFailure:true});
  await f.store.advance(jobId,'alice');const bot=f.state.playerIds[0];
  await assert.rejects(f.store.advance(jobId,'alice'),/transport_failed/);
  assert.equal(f.outbox,false);assert.equal(f.state.playerIds[0],bot);
  f.failPublish(false);await f.store.advance(jobId,'alice');
  assert.equal(f.outbox,true);assert.equal(f.publications.length,1);
});
test('frozen reward roster settles before anonymization; all-bot ownership uses an anonymous non-auth stub',async()=>{
  const f=fixture({pending:true,allBots:true});
  await f.store.advance(jobId,'alice');
  assert.equal(f.settleCount,1);assert.equal(f.state.settlementPending,false);
  assert.equal(f.state.rewardReceiptId,'b'.repeat(64));
  assert.match(f.owner,/^bot_deleted_[a-f0-9]{32}$/);
  assert.ok(f.calls.some(c=>c.startsWith('insert into halabessa.user_profiles')));
  await f.store.advance(jobId,'alice');assert.equal(f.settleCount,1);
});
test('a job lease and completed session block are mandatory before any room mutation',async()=>{
  const f=fixture();f.setLease(false);
  await assert.rejects(f.store.advance(jobId,'alice'),/lease_required/);assert.equal(f.calls.length,0);
  f.setLease(true);f.setStages([]);
  await assert.rejects(f.store.advance(jobId,'alice'),/sessions_not_blocked/);
  assert.equal(f.calls.some(c=>c.startsWith('update')),false);
});
test('unsupported legacy state cannot advance cleanup or delete a shared match',async()=>{
  const f=fixture({legacy:true});
  await assert.rejects(f.store.advance(jobId,'alice'),/unsupported_deletion_room/);
  assert.equal(f.outbox,null);assert.equal(f.state.playerIds[0],'alice');
  assert.equal(f.calls.some(c=>c.startsWith('delete')||c.startsWith('update')),false);
});
test('identity reintroduced before delivery fails closed rather than publishing a stale prepared room',async()=>{
  const f=fixture();await f.store.advance(jobId,'alice');
  f.state.rewardRoster.push('alice');
  await assert.rejects(f.store.advance(jobId,'alice'),/identity_reintroduced/);
  assert.equal(f.publications.length,0);assert.equal(f.outbox,false);
});
