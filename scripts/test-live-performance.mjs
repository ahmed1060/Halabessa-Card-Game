// MANUAL ONLY: run with explicit human approval for ONE new guest/private room.
// Tokens stay in memory. Pause after baseline until the exact canary is enabled.
// This script never uses existing accounts or completes a rewarded match.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { createInterface } from 'node:readline/promises';
if (!process.argv.includes('--live')) throw Error('Explicit --live approval required');
const options=readFileSync('lib/firebase_options.dart','utf8');
const apiKey=/FirebaseOptions web = FirebaseOptions\(\s*apiKey: '([^']+)'/.exec(options)?.[1];
assert.ok(apiKey && options.includes("projectId: 'halabessa-card-game1'"));
const edge='https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api';
const database='https://halabessa-card-game1-default-rtdb.firebaseio.com';
const input=createInterface({input:process.stdin,output:process.stdout});
let account,roomId,current,stage='create guest';
const metrics={baseline:[],canary:[]};
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function json(url,body,token){
  try {
    const started=performance.now();
    const response=await fetch(url,{method:'POST',signal:AbortSignal.timeout(25000),
      headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},
      body:JSON.stringify(body)});
    return {status:response.status,data:await response.json(),ms:Math.round(performance.now()-started)};
  }catch{throw Error(`transport_failed_at_${stage}`);}
}
async function api(action,data={},allowRejected=false){
  const result=await json(edge,{action,...data},account.idToken);
  if(!allowRejected)assert.equal(result.status,200,`${stage}: HTTP ${result.status}/${result.data.error??'unknown'}`);
  return result;
}
function intent(commandType,payload={}){return {roomId,commandType,expectedVersion:current.version,
  commandId:randomUUID(),commandPayload:payload};}
async function command(type,payload={}){
  const result=await api('submitMatchCommand',intent(type,payload));
  current=result.data;return result;
}
function summary(samples){
  const sorted=[...samples].sort((a,b)=>a-b);
  return {n:sorted.length,median_ms:sorted[Math.floor(sorted.length/2)],p95_ms:sorted[Math.ceil(sorted.length*.95)-1]};
}
async function sample(bucket){
  for(let i=0;i<6;i++){
    const result=await command('updateProfile',{displayName:'CodexPerformanceQA',cardBackId:'default_card',avatarUrl:''});
    metrics[bucket].push(result.ms);
    assert.equal(result.data.mirrorPending,bucket==='canary');
  }
}
async function ownView(minVersion){
  const abort=new AbortController();
  const timer=setTimeout(()=>abort.abort(),20000);
  let reader;
  try{
    const started=performance.now();
    const response=await fetch(`${database}/matchViews/${roomId}/${account.uid}.json?auth=${encodeURIComponent(account.idToken)}`,
      {headers:{Accept:'text/event-stream'},signal:abort.signal});
    assert.equal(response.status,200,'own view permission');
    reader=response.body.getReader();let buffer='';const decoder=new TextDecoder();
    while(true){
      const {value,done}=await reader.read();if(done)throw Error('feed_closed');
      buffer+=decoder.decode(value,{stream:true});buffer=buffer.replaceAll('\r\n','\n');
      let end;
      while((end=buffer.indexOf('\n\n'))>=0){
        const frame=buffer.slice(0,end);buffer=buffer.slice(end+2);
        const event=/^event: (.+)$/m.exec(frame)?.[1];
        const data=/^data: (.+)$/m.exec(frame)?.[1];
        if(event==='cancel'||event==='auth_revoked')throw Error('feed_permission_revoked');
        if(event!=='put'||!data)continue;
        const packet=JSON.parse(data),view=packet.path==='/'?packet.data:null;
        if(!view || view.version<minVersion)continue;
        assert.equal(view.recipientUid,account.uid);
        assert.equal(view.state.id,roomId);
        assert.equal('handCards' in view.state,false);
        return {view,ms:Math.round(performance.now()-started)};
      }
    }
  }catch(error){
    if(error instanceof assert.AssertionError)throw error;
    throw Error(`private_feed_failed_at_${stage}`);
  }finally{clearTimeout(timer);abort.abort();await reader?.cancel().catch(()=>{});}
}
try{
  const signed=await json(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,{returnSecureToken:true});
  assert.equal(signed.status,200);account={uid:signed.data.localId,idToken:signed.data.idToken};
  stage='private room';
  const created=await api('createRoom',{protocolVersion:1,mode:'classic',maxPoints:41,timerDurationSeconds:0,
    isPublic:false,displayName:'CodexPerformanceQA',cardBackId:'default_card',avatarUrl:''});
  roomId=created.data.roomId;assert.match(roomId,/^[A-Z]{3}\d{5}$/);
  current=(await api('getMatchSnapshot',{roomId})).data;
  console.log(JSON.stringify({fixture:{roomId,uid:account.uid},created:true}));
  stage='baseline profile commands';await sample('baseline');
  console.log(JSON.stringify({baseline:summary(metrics.baseline)}));
  assert.equal((await input.question('Enable only this room canary, then type CANARY: ')).trim(),'CANARY');
  stage='canary profile commands';await sample('canary');
  console.log(JSON.stringify({canary:summary(metrics.canary)}));
  stage='bot preparation';await command('voteForBots');await command('startRound');
  await sleep(1100);await command('advance');
  await sleep(2100);await command('advance');
  await sleep(5100);await command('advance');
  for(let i=0;i<15 && (current.state.phase!=='playing'||current.state.playerIds[current.state.currentTurnIndex]!==account.uid);i++){
    await sleep(current.state.phase==='capturing'?1300:1100);await command('advance');
  }
  assert.equal(current.state.phase,'playing');
  assert.equal(current.state.playerIds[current.state.currentTurnIndex],account.uid);
  assert.equal(current.hand.length,4);
  stage='competing real card plays';const version=current.version;
  const competing=current.hand.slice(0,2).map(card=>intent('playCard',{card}));
  const results=await Promise.all(competing.map(body=>api('submitMatchCommand',body,true)));
  assert.equal(results.filter(r=>r.status===200).length,1);
  assert.equal(results.filter(r=>r.status===409 && r.data.error==='version_conflict').length,1);
  const winner=results.findIndex(r=>r.status===200);current=results[winner].data;
  assert.equal(current.version,version+1);assert.equal(current.hand.length,3);
  const retry=(await api('submitMatchCommand',competing[winner])).data;
  assert.equal(retry.duplicate,true);assert.equal(retry.appliedVersion,version+1);assert.equal(retry.hand.length,3);
  stage='stream delivery';const delivered=await ownView(current.version);
  assert.equal((delivered.view.hand??[]).length,3);
  stage='reconnect';const reconnected=await ownView(current.version);
  assert.ok(reconnected.view.version>=delivered.view.version);
  console.log(JSON.stringify({passed:true,concurrentAccepted:1,concurrentRejected:1,retryDidNotReplay:true,
    deliveredVersion:delivered.view.version,reconnectedVersion:reconnected.view.version,
    reconnect_ms:reconnected.ms,baseline:summary(metrics.baseline),canary:summary(metrics.canary)}));
}catch(error){
  console.error(JSON.stringify({passed:false,stage,message:error instanceof assert.AssertionError?'assertion_failed':error.message}));
  process.exitCode=1;
}finally{
  // Keep the token available while the narrowly scoped teardown adapter is
  // installed. It must verify this exact canary/private/sole-human room.
  if(roomId&&account){
    console.log(JSON.stringify({cleanupRequired:{roomId,uid:account.uid}}));
    if((await input.question('Install exact-fixture cleanup, then type CLEANUP: ')).trim()==='CLEANUP'){
      try{
        stage='room cleanup';const cleaned=await api('cleanupPerformanceFixture',{roomId});
        assert.equal(cleaned.data.ok,true);
        const deleted=await json(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${apiKey}`,{idToken:account.idToken});
        assert.equal(deleted.status,200);
        console.log(JSON.stringify({roomCleaned:true,accountDeleted:true,sqlProfileCleanupRequired:account.uid}));
      }catch{console.error(JSON.stringify({cleanupFailed:true,roomId,uid:account.uid}));process.exitCode=1;}
    }
  }
  input.close();
}
