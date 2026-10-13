import test from 'node:test';
import assert from 'node:assert/strict';
import { atomicCaptureSupported, declareCapturePresentation } from '../../supabase/functions/halabessa-api/capture_presentation.ts';
import { lifecycleCommand, advanceMatch } from '../../supabase/functions/halabessa-api/match_lifecycle.ts';
import type { MatchState } from '../../supabase/functions/halabessa-api/match_engine.ts';
const now = Date.parse('2026-10-12T10:00:00Z');
const card = (suit: string, rank: string) => ({suit,rank});
function room(): MatchState {
  return {id:'ABC12345', protocolVersion:1, serverVersion:10, matchSequence:2, roundCount:3,
    playerIds:['a','bot_2','b','bot_4'], currentTurnIndex:0, phase:'playing', mode:'classic',
    turnStartTime:new Date(now).toISOString(), timerDurationSeconds:15,
    board:[card('hearts','ace')], handCards:{a:[card('spades','ace'),card('clubs','king')],
      bot_2:[card('diamonds','two'),card('hearts','two')], b:[card('clubs','three'),card('hearts','four')],bot_4:[]}};
}
test('all humans must negotiate capture; old/missing clients downgrade safely', () => {
  let state = declareCapturePresentation(room(),'a',2);
  assert.equal(atomicCaptureSupported(state),false);
  state = declareCapturePresentation(state,'b',2);
  assert.equal(atomicCaptureSupported(state),true);
  assert.equal(atomicCaptureSupported(declareCapturePresentation(state,'b',undefined)),false);
  assert.equal(atomicCaptureSupported({...state,protocolVersion:0}),false);
  assert.equal(atomicCaptureSupported({...state,playerIds:['bot_1','bot_2','bot_3','bot_4']}),false);
});
test('capture commits empty authoritative board and next bot deadline with one move', () => {
  const before = declareCapturePresentation(declareCapturePresentation(room(),'a',2),'b',2);
  const after = lifecycleCommand('playCard', before, [],'a',{card:before.handCards!.a[0]},now).state;
  assert.equal(after.phase,'playing'); assert.deepEqual(after.board,[]);
  assert.equal(after.currentTurnIndex,1); assert.equal(after.handCards!.a.length,1);
  const event = (after.captureEvents as any[])[0];
  assert.equal(event.id,'2:3:11'); assert.equal(event.playerUid,'a');
  assert.deepEqual(event.cards,[before.board![0],before.handCards!.a[0]]);
  assert.equal('handCards' in event,false);
  assert.throws(()=>advanceMatch(after,[],now+1399),/no_transition_due/);
  assert.equal(advanceMatch(after,[],now+1400).state.handCards!.bot_2.length,1);
  assert.equal(before.handCards!.a.length,2); // input and event are immutable snapshots
});
test('legacy capture still needs its compatible phase; human deadline gets visual grace', () => {
  const original=room();
  assert.equal(lifecycleCommand('playCard',original,[],'a',{card:original.handCards!.a[0]},now).state.phase,'capturing');
  let before={...original,playerIds:['a','b','bot_3','bot_4']};
  before=declareCapturePresentation(declareCapturePresentation(before,'a',2),'b',2) as typeof before;
  const after=lifecycleCommand('playCard',before,[],'a',{card:before.handCards!.a[0]},now).state;
  assert.equal(Date.parse(String(after.turnStartTime)),now+1400);
  assert.throws(()=>lifecycleCommand('playCard',after,[],'b',{card:after.handCards!.b[0]},now+1),/capture_presentation_pending/);
  assert.equal(lifecycleCommand('playCard',after,[],'b',{card:after.handCards!.b[0]},now+1400).state.currentTurnIndex,2);
});

test('atomic full round conserves 52 cards without a decorative completion mutation', () => {
  const initial: MatchState={id:'ABC12345',protocolVersion:1,serverVersion:0,
    phase:'waitingForPlayers',mode:'classic',playerIds:['a','b','c','d'],
    capturePresentationByPlayer:{a:2,b:2,c:2,d:2},maxPoints:1,timerDurationSeconds:15};
  let clock=now, {state,deck}=advanceMatch(initial,[],clock), plays=0, captures=0;
  ({state,deck}=lifecycleCommand('cut',state,deck,'d',{position:20},clock));
  for(let step=0;step<100 && state.phase!=='rematchVoting';step++){
    if(state.phase==='playing' && state.playerIds!.some(uid=>state.handCards?.[uid]?.length)){
      const uid=state.playerIds![Number(state.currentTurnIndex)],hand=state.handCards![uid];
      const card=hand.find(c=>c.rank===state.board?.at(-1)?.rank)??hand[0];
      clock=Math.max(clock+1000,Date.parse(String(state.playAvailableAt??''))||0);
      const before=(state.captureEvents as unknown[]??[]).length;
      ({state,deck}=lifecycleCommand('playCard',state,deck,uid,{card},clock));plays++;
      captures+=(state.captureEvents as unknown[]??[]).length-before;
      state={...state,serverVersion:Number(state.serverVersion)+1};
      assert.equal(state.phase,'playing');
    } else {clock+=state.phase==='roundScoring'?8000:5000;({state,deck}=advanceMatch(state,deck,clock));}
    const harvested=Object.values(state.harvestStacks as Record<string,any[]>??{})
      .flatMap(stack=>stack.flatMap(c=>[...c.capturedCards,c.leadingCard]));
    const physical=[...deck,...(state.board??[]),...Object.values(state.handCards??{}).flat(),...harvested];
    assert.equal(physical.length,52);
    assert.equal(new Set(physical.map(c=>`${c.suit}_${c.rank}`)).size,52);
  }
  assert.equal(plays,48);assert.ok(captures>0);assert.equal(state.phase,'rematchVoting');
  assert.equal(state.settlementPending,true);
});
