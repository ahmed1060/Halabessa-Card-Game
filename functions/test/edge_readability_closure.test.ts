import test from 'node:test';
import assert from 'node:assert/strict';
import { releasePlayer, timeoutPlay } from '../../supabase/functions/halabessa-api/turn_policy.ts';
import { closeEmptyRoom } from '../../supabase/functions/halabessa-api/room_closure.ts';
import { lifecycleCommand, advanceMatch } from '../../supabase/functions/halabessa-api/match_lifecycle.ts';
import { progressDeadline } from '../../supabase/functions/halabessa-api/match_progress.ts';
import { roomSummary } from '../../supabase/functions/halabessa-api/room_summary.ts';
import { joinCommandRoom } from '../../supabase/functions/halabessa-api/room_seating.ts';
import { assignBotDifficulties } from '../../supabase/functions/halabessa-api/bot_strategy.ts';
import { publishDetachedRoom } from '../../supabase/functions/halabessa-api/room_publication.ts';
import type { MatchState } from '../../supabase/functions/halabessa-api/match_engine.ts';

const now = Date.parse('2026-10-12T14:00:00Z');
const card = (rank: string) => ({suit:'hearts',rank});
function room(): MatchState {
  return {id:'ABC12345', protocolVersion:1, serverVersion:4, isPublic:true,
    phase:'playing', playerIds:['a','bot_2','bot_3','bot_4'], currentTurnIndex:0,
    timerDurationSeconds:15,turnStartTime:new Date(now).toISOString(),
    capturePresentationByPlayer:{a:2}, board:[card('ace')],
    handCards:{a:[{suit:'clubs',rank:'ace'},card('king')],
      bot_2:[card('two'),card('three')],bot_3:[card('four')],bot_4:[card('five')]}};
}
test('last confirmed departure closes, clears private play state and rejects recovery',()=>{
  const before=room();
  const after=lifecycleCommand('leave',before,[card('six')],'a',{},now);
  assert.equal(after.state.roomClosed,true); assert.equal(after.state.phase,'matchOver');
  assert.deepEqual(after.state.playerIds,[]); assert.deepEqual(after.state.handCards,{});
  assert.deepEqual(after.deck,[]); assert.equal(roomSummary(after.state).isPublic,false);
  assert.equal(progressDeadline(after.state),null);
  assert.throws(()=>joinCommandRoom(after.state,'new',{displayName:'New',cardBackId:'default',avatarUrl:''}),/room_closed/);
  assert.equal(before.playerIds!.length,4);
});
test('presence loss alone and departure with another human do not close the room',()=>{
  const before={...room(),playerIds:['a','b','bot_3','bot_4']};
  assert.equal(closeEmptyRoom({...before,playerOnlineStatus:{a:false,b:false}}).roomClosed,undefined);
  const after=releasePlayer(before,'a','left',now);
  assert.notEqual(after.roomClosed,true); assert.ok(after.playerIds!.includes('b'));
  assert.equal(after.playerIds![0].startsWith('bot_'),true);
});
test('third timeout closes a last-human room, not the first or second timeout',()=>{
  for(const count of [0,1,2]) {
    const after=timeoutPlay({...room(),consecutiveTimeouts:{a:count}},now+15000);
    assert.equal(after.roomClosed===true,count===2);
  }
});
test('closure retains completed-match settlement identity and awards',()=>{
  const before={...room(),phase:'rematchVoting',settlementPending:true,
    rewardRoster:['a','bot_2','bot_3','bot_4'],rewardScores:{teamA:41,teamB:20},earnedCoins:{a:100}};
  const closed=releasePlayer(before,'a','left',now);
  assert.equal(closed.settlementPending,true);
  assert.deepEqual(closed.rewardRoster,before.rewardRoster);
  assert.deepEqual(closed.earnedCoins,{a:100});
});
test('online assigns only medium/hard/expert and replaces previously easy bots',()=>{
  for(const [n,level] of [[0,'medium'],[0.34,'hard'],[0.99,'expert']] as const){
    const assigned=assignBotDifficulties({...room(),botDifficulties:{bot_2:'easy'}},()=>n);
    assert.equal((assigned.botDifficulties as any).bot_2,level);
    assert.equal(JSON.stringify(assigned.botDifficulties).includes('easy'),false);
    assert.deepEqual(assignBotDifficulties(assigned,()=>0).botDifficulties,assigned.botDifficulties);
  }
});
test('capture reading barrier blocks bots, forced cards and early human commands',()=>{
  for(const ids of [['a','bot_2','bot_3','bot_4'],['a','b','bot_3','bot_4']]){
    const before={...room(),playerIds:ids, capturePresentationByPlayer:{a:2,b:2},
      handCards:{...room().handCards,b:[card('two'),card('three')]}};
    const after=lifecycleCommand('playCard',before,[],'a',{card:before.handCards.a[0]},now).state;
    assert.equal(Date.parse(String(after.playAvailableAt)),now+1400);
    assert.throws(()=>advanceMatch(after,[],now+1399),/no_transition_due/);
    if(ids[1]==='b') {
      assert.throws(()=>lifecycleCommand('playCard',after,[],'b',{card:card('two')},now+1),/capture_presentation_pending/);
      assert.equal(lifecycleCommand('playCard',after,[],'b',{card:card('two')},now+1400).state.currentTurnIndex,2);
      assert.equal(Date.parse(String(after.turnStartTime)),now+1400);
    } else {
      assert.equal(progressDeadline(after),now+1400);
      assert.equal(advanceMatch(after,[],now+1400).state.currentTurnIndex,2);
      assert.equal(progressDeadline({...after,handCards:{...after.handCards,bot_2:[card('two')]}}),now+1400);
    }
  }
});
test('closed-room purge waits for fenced delivery and retains pending rewards',async()=>{
  for(const pending of [false,true]) {
    const calls:string[]=[]; let delivered=false,active=0;
    const query=async(sql:string)=>{
      calls.push(sql);
      if(sql.startsWith('select r.state'))return [{state:{...closeEmptyRoom({...room(),playerIds:[]},now),settlementPending:pending},version:'5',hands:{}}];
      if(sql.startsWith('delete from halabessa.rooms'))assert.equal(delivered,true);
      return [];
    };
    const run=async<T>(work:any)=>{active++;try{return await work(query) as T;}finally{active--;}};
    await publishDetachedRoom(run,'ABC12345',async()=>{assert.equal(active,0);delivered=true;});
    assert.equal(calls.some(sql=>sql.startsWith('delete from halabessa.rooms')),!pending);
  }
});
