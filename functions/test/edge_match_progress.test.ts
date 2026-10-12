import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { BOT_THINK_MS, FORCED_CARD_MS, CAPTURE_MS, progressDeadline, progressEnabled } from '../../supabase/functions/halabessa-api/match_progress.ts';
import { advanceMatch } from '../../supabase/functions/halabessa-api/match_lifecycle.ts';
import { publicMatchState } from '../../supabase/functions/halabessa-api/match_delivery.ts';
import { advanceScheduledRoom, runRoomProgress } from '../../supabase/functions/halabessa-api/match_progress_worker.ts';
import type { MatchState } from '../../supabase/functions/halabessa-api/match_engine.ts';
import type { PublicationQuery } from '../../supabase/functions/halabessa-api/room_publication.ts';

const start = Date.parse('2026-10-12T08:00:00Z');
const card = (rank: string) => ({suit:'hearts',rank});
test('Training and countdown policy match the server reading beats', () => {
  const timing = readFileSync(new URL('../../lib/features/game/domain/logic/match_presentation_timing.dart', import.meta.url), 'utf8');
  assert.match(timing, new RegExp(`botThinkDuration = Duration\\(milliseconds: ${BOT_THINK_MS}\\)`));
  assert.match(timing, new RegExp(`lastCardAutoPlayDuration = Duration\\(milliseconds: ${FORCED_CARD_MS}\\)`));
  assert.match(timing, new RegExp(`captureTotalDuration = Duration\\(milliseconds: ${CAPTURE_MS}\\)`));
  assert.ok(BOT_THINK_MS > CAPTURE_MS);
  assert.ok(FORCED_CARD_MS > CAPTURE_MS);
});
function room(): MatchState {
  return {id:'ABC12345',protocolVersion:1,phase:'playing',playerIds:['a','bot_1','b','bot_2'],
    currentTurnIndex:1,dealerIndex:0,timerDurationSeconds:15,
    turnStartTime:new Date(start).toISOString(),phaseStartedAt:new Date(start).toISOString(),
    handCards:{a:[card('ace'),card('two')],bot_1:[card('three'),card('four')],
      b:[card('five'),card('six')],bot_2:[card('seven'),card('eight')]},board:[]};
}

test('bot policy leaves an 800ms reading beat; last card leaves 900ms', () => {
  for (const level of ['easy','medium','hard','expert']) {
    const state = {...room(),botDifficulties:{bot_1:level}};
    assert.equal(progressDeadline(state),start+800);
    assert.throws(()=>advanceMatch(state,[],start+799),/no_transition_due/);
    assert.equal(advanceMatch(state,[],start+800).state.handCards!.bot_1.length,1);
    const single = {...state,handCards:{...state.handCards,bot_1:[card('four')]}};
    assert.equal(progressDeadline(single),start+900);
    assert.throws(()=>advanceMatch(single,[],start+899),/no_transition_due/);
  }
});
test('public deadlines contain no opponent hands and work with counts alone', () => {
  const snapshot=publicMatchState(room(),3);
  assert.equal(snapshot.progressDueAt,new Date(start+800).toISOString());
  assert.equal(snapshot.handCards,undefined);
  assert.equal(progressDeadline(snapshot),start+800);
  assert.equal(progressDeadline({...snapshot,currentTurnIndex:0,timerDurationSeconds:0}),null);
  assert.equal(progressDeadline({...snapshot,currentTurnIndex:0}),start+15000);
});
test('phase deadlines preserve memory and ten-second voting policies', () => {
  const s=room();
  for (const [phase,wait] of [['dealingFasha',2000],['dealingCards',5000],['capturing',600],['roundScoring',5000],['shuffleVoting',10000]]) {
    assert.equal(progressDeadline({...s,phase}),start+Number(wait));
  }
  assert.equal(progressDeadline({...s,phase:'shuffleVoting',shuffleVotes:{a:true,b:false}}),0);
  assert.equal(progressDeadline({...s,phase:'rematchVoting',settlementPending:true,rematchVotes:{a:true,b:true}}),null);
  assert.equal(progressDeadline({...s,phase:'matchOver'}),null);
});
test('disabled, unattended and incomplete rooms do not run', () => {
  assert.equal(progressEnabled(undefined,'ABC12345'),false);
  assert.equal(progressEnabled({progress_enabled:true},'../secret'),false);
  assert.equal(progressEnabled({progress_canary_room_id:'ABC12345'},'ABC12345'),true);
  assert.equal(progressEnabled({progress_canary_room_id:'ABC12345'},'XYZ99999'),false);
  assert.equal(progressDeadline({...room(),playerIds:['bot_0','bot_1','bot_2','bot_3']}),null);
  assert.equal(progressDeadline({...room(),phase:'waitingForPlayers',playerIds:['a','waiting_1','b','waiting_2']}),null);
});

function queryFixture(state=room(),version=3) {
  const calls: string[]=[];
  let storedState=publicMatchState(state,version),hands=state.handCards!;
  let queued=version;
  const query: PublicationQuery=async(sql,args)=> {
    calls.push(sql);
    if(sql.includes('select r.state'))return [{state:storedState,version:String(version),hands,deck:[],queued_version:String(queued)}];
    if(sql.startsWith('update halabessa.rooms')){storedState=JSON.parse(String(args[1]));version=Number(args[2]);queued=version;}
    if(sql.startsWith('update halabessa.room_secrets'))hands=JSON.parse(String(args[1]));
    return [];
  };
  return {query,calls,get state(){return storedState;},get hands(){return hands;},setQueued:(n:number)=>queued=n};
}
test('worker uses room locks, commits one move and rechecks a duplicate invocation',async()=> {
  const f=queryFixture();
  assert.equal(await advanceScheduledRoom(f.query,'ABC12345',()=>start+800),true);
  assert.equal(f.hands.bot_1.length,1);
  assert.match(f.calls[1],/for update of r,s skip locked/);
  assert.equal(f.calls.at(-1),'commit');
  assert.equal(await advanceScheduledRoom(f.query,'ABC12345',()=>start+800),false);
  assert.equal(f.hands.bot_1.length,1);
  assert.equal(f.calls.at(-1),'rollback');
});
test('automatic timing contains fixed categories only; diagnostic failure cannot roll back a move',async()=> {
  const f=queryFixture(); const records: unknown[]=[];
  assert.equal(await advanceScheduledRoom(f.query,'ABC12345',()=>start+850,record=>{
    records.push(record);throw Error('logger_unavailable');
  }),true);
  assert.equal(f.calls.at(-1),'commit');
  const record=records[0] as Record<string,unknown>;
  assert.deepEqual(Object.keys(record).sort(),['due_lag_ms','engine_ms','event','transaction_ms','transition']);
  assert.equal(record.transition,'bot_play');assert.equal(record.due_lag_ms,50);
  assert.equal(JSON.stringify(record).includes('ABC12345'),false);
  assert.equal(JSON.stringify(record).includes('bot_1'),false);
});
test('stale job fails closed; validation failure rolls back without publication',async()=> {
  const f=queryFixture();f.setQueued(2);
  await assert.rejects(advanceScheduledRoom(f.query,'ABC12345',()=>start+800),/invalid_progress_revision/);
  assert.equal(f.calls.at(-1),'rollback');
  assert.equal(f.calls.some(s=>s.startsWith('update')),false);
  await assert.rejects(advanceScheduledRoom(f.query,'../../bad'),/invalid_room_id/);
});
test('disabled/locked room never advances',async()=> {
  const calls:string[]=[];
  assert.equal(await advanceScheduledRoom(async sql=>{calls.push(sql);return [];},'ABC12345'),false);
  assert.deepEqual(calls.filter(s=>s==='begin'||s==='rollback'),['begin','rollback']);
});
test('waiting holds no database runner; bounded task leaves distant jobs durable',async()=> {
  let active=false,time=start,reads=0,slept=0;
  const run=async<T>(work:(query:PublicationQuery)=>Promise<T>)=>{
    assert.equal(active,false);active=true;
    try{return await work(async sql=>{reads++;return sql.startsWith('select p.due_at')?[{due_at:new Date(start+30000)}]:[];});}
    finally{active=false;}
  };
  assert.equal(await runRoomProgress(run,'ABC12345',async()=>assert.fail('no move'),{
    now:()=>time,elapsed:()=>time-start,sleep:async ms=>{assert.equal(active,false);slept+=ms;time+=ms;},
  }),0);
  assert.equal(slept,0);assert.equal(reads,1);
});
test('scheduler sleeps outside runner and publishes only after commit',async()=> {
  const f=queryFixture();let active=false,time=start,published=0;
  const run=async<T>(work:(query:PublicationQuery)=>Promise<T>)=>{
    active=true;try{return await work(async(sql,args)=>sql.startsWith('select p.due_at')
      ? [{due_at:new Date(progressDeadline({...f.state,handCards:f.hands})!)}]
      : f.query(sql,args));}finally{active=false;}
  };
  assert.equal(await runRoomProgress(run,'ABC12345',async()=>{
    assert.equal(active,false);assert.equal(f.calls.at(-1),'commit');published++;
  },{maxSteps:1,now:()=>time,elapsed:()=>time-start,sleep:async ms=>{assert.equal(active,false);time+=ms;}}),1);
  assert.equal(time,start+800);assert.equal(published,1);
});

test('consecutive automatic moves reuse only committed deadline hints, with no extra job-read connection',async()=> {
  const f=queryFixture();let time=start,reads=0,published=0;
  const run=async<T>(work:(query:PublicationQuery)=>Promise<T>)=>work(async(sql,args)=>{
    if(sql.startsWith('select p.due_at')) {reads++;return [{due_at:new Date(start+800)}];}
    return f.query(sql,args);
  });
  // The bot moves once, then the next human times out. Both must be locked
  // and revalidated; the committed hint is only a sleeping optimization.
  assert.equal(await runRoomProgress(run,'ABC12345',async()=>{published++;},{maxSteps:2,
    now:()=>time,elapsed:()=>time-start,sleep:async ms=>{time+=ms;}}),2);
  assert.equal(reads,1);assert.equal(published,2);
  assert.equal(f.calls.filter(sql=>sql.includes('for update of r,s skip locked')).length,2);
});

test('a timer-free human decision stops the chain without another connection',async()=> {
  const f=queryFixture({...room(),timerDurationSeconds:0});let time=start,reads=0;
  const run=async<T>(work:(query:PublicationQuery)=>Promise<T>)=>work(async(sql,args)=>{
    if(sql.startsWith('select p.due_at')) {reads++;return [{due_at:new Date(start+800)}];}
    return f.query(sql,args);
  });
  assert.equal(await runRoomProgress(run,'ABC12345',async()=>{}, {
    now:()=>time,elapsed:()=>time-start,sleep:async ms=>{time+=ms;}}),1);
  assert.equal(reads,1);
});
