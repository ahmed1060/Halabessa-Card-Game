import test from 'node:test';
import assert from 'node:assert/strict';
import {anonymizeDeletedPlayer} from '../../supabase/functions/halabessa-api/deletion_room_state.ts';
const anonymous='bot_deleted_'+'a'.repeat(32);
function state() {
  return {protocolVersion:1,serverVersion:4,phase:'playing',playerIds:['alice','bob','bot_3','bot_4'],
    players:{alice:true,bob:true,bot_3:true,bot_4:true},
    playerNames:{alice:'Private name',bob:'Bob'},playerAvatars:{alice:'private-photo',bob:'bob-photo'},
    handCards:{alice:[{rank:'ace',suit:'hearts'}],bob:[{rank:'king',suit:'clubs'}]},
    teamAScore:12,teamBScore:6,currentTurnIndex:0,
    releasedSeats:{old_bot:{previousUid:'alice',reason:'left'}},
    cardOwnership:{hearts_ace:'alice'}, rewardRoster:['alice','bob','bot_3','bot_4'],
    captures:[{playedBy:'alice',playerName:'Private name',leadingCard:{rank:'ace',suit:'hearts'}}],
    skippedMatches:{bob:['ace:alice']},settlementPending:false};
}
test('deletion uses leave/bot takeover while preserving cards, scores and unrelated players',()=>{
  const input=state(),result=anonymizeDeletedPlayer(input,'alice',anonymous);
  const bot=result.playerIds![0];
  assert.match(bot,/^bot_/);assert.equal(result.playerIds![1],'bob');
  assert.deepEqual(result.handCards?.[bot],input.handCards.alice);
  assert.deepEqual(result.handCards?.bob,input.handCards.bob);
  assert.equal(result.teamAScore,12);assert.equal(result.teamBScore,6);
  assert.equal((result.playerNames as any).bob,'Bob');assert.equal((result.playerAvatars as any).bob,'bob-photo');
  assert.equal(JSON.stringify(result).includes('alice'),false);
  assert.equal(JSON.stringify(result).includes('Private name'),false);
  assert.equal(JSON.stringify(result).includes('private-photo'),false);
  assert.deepEqual(input,state());
});
test('pending settlement and unsupported legacy rooms fail closed instead of losing rewards',()=>{
  assert.throws(()=>anonymizeDeletedPlayer({...state(),settlementPending:true},'alice',anonymous),/settlement_required/);
  assert.throws(()=>anonymizeDeletedPlayer({...state(),protocolVersion:0},'alice',anonymous),/unsupported_deletion_room/);
});
test('departed players are anonymized without evicting their replacements',()=>{
  const input=state();input.playerIds[0]='bot_1';delete (input.players as any).alice;
  const result=anonymizeDeletedPlayer(input,'alice',anonymous);
  assert.deepEqual(result.playerIds,input.playerIds);
  assert.equal(JSON.stringify(result).includes('alice'),false);
  assert.equal((result.captures as any)[0].playerName,'Deleted player');
});
