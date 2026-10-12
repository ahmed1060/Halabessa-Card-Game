// MANUAL ONLY. Requires prior human approval for exactly one disposable guest
// and one private room. No reward completion, real accounts, or secrets logged.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {createInterface} from 'node:readline/promises';
import {RevisionTracker} from './performance-feed.mjs';
if (!process.argv.includes('--live')) throw Error('Explicit live approval required');
// Historical operator harness, never CI. The exact-fixture helpers used for
// the recorded QA were removed from production. Refuse new fixtures unless
// the operator has installed approved, fixture-bound recovery/teardown tools.
if (!process.argv.includes('--fixture-tools-installed')) {
  throw Error('Temporary fixture-bound tools and cleanup approval required; production has no QA endpoints');
}
const options=readFileSync('lib/firebase_options.dart','utf8');
const key=/FirebaseOptions web = FirebaseOptions\(\s*apiKey: '([^']+)'/.exec(options)?.[1];
assert.ok(key);
const edge='https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api';
// Match the released client's read/command route, not the CLI's geolocation.
const region=process.argv.includes('--automatic-region')?null:'eu-west-2';
const db='https://halabessa-card-game1-default-rtdb.firebaseio.com';
const input=createInterface({input:process.stdin,output:process.stdout});
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let account,id,current,reader,abort,tracker,consume,latestView,canary=false,stage='create';
const measurements={baseline:{ack:[],visible:[]},canary:{ack:[],visible:[]}};
async function json(url,body,token) {
  const response=await fetch(url,{method:'POST',signal:AbortSignal.timeout(30000),
    headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{ }),
      ...(url===edge&&region&&['getMatchSnapshot','submitMatchCommand'].includes(body.action)?{'x-region':region}:{})},body:JSON.stringify(body)});
  return {status:response.status,data:await response.json()};
}
async function api(action,data={},allowFailure=false) {
  const result=await json(edge,{action,...data},account.idToken);
  if (!allowFailure) assert.equal(result.status,200,`${stage}/${action}: ${result.status}/${result.data.error}`);
  return result;
}
async function snapshot() {
  current=(await api('getMatchSnapshot',{roomId:id})).data;
  return current;
}
async function command(type,payload={},sample=false) {
  const body={roomId:id,commandId:randomUUID(),commandType:type,
    expectedVersion:current.version,commandPayload:payload,...(canary?{capturePresentationVersion:2}:{})};
  const started=performance.now();
  const delivery=tracker?.wait(current.version+1,started).then(v=>({v}),()=>({failed:true}));
  const result=await api('submitMatchCommand',body,true);
  if (result.status===409 && result.data.error==='version_conflict') {
    current=result.data; return false; // definite rejection, no ambiguous replay
  }
  assert.equal(result.status,200,`${stage}/${type}: ${result.status}/${result.data.reason??result.data.error}`);
  const ack=performance.now()-started; current=result.data;
  if (delivery) {
    const delivered=await delivery;assert.equal(delivered.failed,undefined,'private feed timeout');
    if(sample){const bucket=canary?'canary':'baseline';measurements[bucket].ack.push(Math.round(ack));measurements[bucket].visible.push(delivered.v.ms);}
  }
  return true;
}
async function openFeed() {
  abort=new AbortController(); tracker=new RevisionTracker(account.localId,id);
  const response=await fetch(`${db}/matchViews/${id}/${account.localId}.json?auth=${encodeURIComponent(account.idToken)}`,
    {headers:{Accept:'text/event-stream'},signal:abort.signal});
  assert.equal(response.status,200);reader=response.body.getReader();
  consume=(async()=>{let buffer='';const decoder=new TextDecoder();
    while(true){const {value,done}=await reader.read();if(done)throw Error('feed_closed');
      buffer+=decoder.decode(value,{stream:true});buffer=buffer.replaceAll('\r\n','\n');let end;
      while((end=buffer.indexOf('\n\n'))>=0){const frame=buffer.slice(0,end);buffer=buffer.slice(end+2);
        if(/^event: (cancel|auth_revoked)/m.test(frame))throw Error('feed_denied');
        const data=/^data: (.+)$/m.exec(frame)?.[1];if(!/^event: put$/m.test(frame)||!data)continue;
        const packet=JSON.parse(data);if(packet.path==='/'&&packet.data){tracker.observe(packet.data);latestView=packet.data;}
      }
    }
  })().catch(()=>tracker.fail());
  await tracker.wait(current.version);
}
async function closeFeed() {tracker?.fail();abort?.abort();await reader?.cancel().catch(()=>{});await consume;}
async function humanTurn() {
  // The legacy path requires a request per bot. Allow that network baseline
  // enough time; do not confuse a QA timeout with an authoritative stall.
  const until=Date.now()+(canary?150000:240000);
  while(Date.now()<until){
    if (canary && latestView && latestView.version >= current.version) current=latestView;
    else if (!canary) await snapshot();
    const s=current.state;
    if(s.phase==='playing'&&s.playerIds[s.currentTurnIndex]===account.localId&&current.hand.length>1)return;
    assert.ok(!['rematchVoting','matchOver'].includes(s.phase),'QA must not finish rewarded match');
    if(canary){await sleep(250);continue;} // prove server progress with NO advance commands
    const start=Date.parse(s.phaseStartedAt??s.turnStartTime),turn=Date.parse(s.turnStartTime);
    const phaseMs={preRoundCut:1000,dealingFasha:2000,dealingCards:5000,capturing:600,roundScoring:5000}[s.phase];
    const due=phaseMs!==undefined?start+phaseMs:s.phase==='playing'?turn+(current.hand.length===1&&s.playerIds[s.currentTurnIndex]===account.localId?600:1000):Date.now();
    await sleep(Math.max(50,due-Date.now()+40));
    await command('advance');
  }
  throw Error('server_progress_stalled');
}
function summary(values){const sorted=[...values].sort((a,b)=>a-b);return{n:values.length,
  median_ms:sorted[Math.floor(sorted.length/2)],p95_ms:sorted[Math.ceil(sorted.length*.95)-1]};}
function report(){return Object.fromEntries(Object.entries(measurements).map(([bucket,data])=>[bucket,
  {ack:summary(data.ack),own_private_view:summary(data.visible)}]));}
try {
  if(process.argv.includes('--resume')) {
    id=process.argv[process.argv.indexOf('--resume')+1];
    assert.match(id,/^[A-Z]{3}[0-9]{5}$/);
    // A one-time, fixture-bound custom token restores the SAME guest. It is
    // read from stdin, never arguments/files/logs. No new account is created.
    const token=(await input.question('Fixture token: ')).trim();
    const restored=await json(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${key}`,
      {token,returnSecureToken:true});
    assert.equal(restored.status,200);account=restored.data;
    account.localId=JSON.parse(Buffer.from(account.idToken.split('.')[1],'base64url').toString()).sub;
  } else {
    const guest=await json(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${key}`,{returnSecureToken:true});
    assert.equal(guest.status,200);account=guest.data;
    const created=await api('createRoom',{mode:'classic',maxPoints:41,timerDurationSeconds:0,
      isPublic:false,displayName:'CodexFlowQA',cardBackId:'default_card',avatarUrl:'',protocolVersion:1});
    id=created.data.roomId;
  }
  await snapshot();
  console.log(JSON.stringify({fixture:{roomId:id,uid:account.localId}}));
  stage='baseline';
  if(current.state.phase==='waitingForPlayers'){await command('voteForBots');await command('advance');}
  await openFeed();
  for(let count=0;count<(process.argv.includes('--canary-only')?0:4);){await humanTurn();
    const top=current.state.board?.at(-1);const card=current.hand.find(c=>c.rank===top?.rank)??current.hand[0];
    if(await command('playCard',{card},true))count++;
  }
  console.log(JSON.stringify({baseline:report().baseline,pause:'Deploy code and enable ONLY this canary; type CANARY'}));
  if((await input.question('CANARY: ')).trim()!=='CANARY')throw Error('canary_not_enabled');
  canary=true;stage='canary';await snapshot();
  await command('updateProfile',{displayName:'CodexFlowQA',cardBackId:'default_card',avatarUrl:''});
  let captures=0;
  for(let count=0;count<4;){await humanTurn();
    const before=(current.state.captureEvents??[]).length;
    const top=current.state.board?.at(-1);const card=current.hand.find(c=>c.rank===top?.rank)??current.hand[0];
    if(await command('playCard',{card},true)){count++;captures+=Math.max(0,(current.state.captureEvents??[]).length-before);
      assert.equal(current.state.phase,'playing','capture must not require second command');}
  }
  stage='duplicate and reconnect';await snapshot();
  const intent={roomId:id,commandId:randomUUID(),commandType:'updateProfile',expectedVersion:current.version,
    capturePresentationVersion:2,commandPayload:{displayName:'CodexFlowQA',cardBackId:'default_card',avatarUrl:''}};
  const accepted=await api('submitMatchCommand',intent,true);
  if(accepted.status===200){const repeated=await api('submitMatchCommand',intent);assert.equal(repeated.data.duplicate,true);assert.equal(repeated.data.appliedVersion,accepted.data.version);}
  await closeFeed();await snapshot();await openFeed();assert.ok(latestView.version>=current.version);
  console.log(JSON.stringify({passed:true,measurements:report(),manualCapturesVerified:captures,
    canaryAdvanceRequests:0,reconnectPassed:true,commandRegion:region??'automatic',sampleConditions:'CLI/desktop network; four manual plays per bucket, not phone p95'}));
}catch(error){console.error(JSON.stringify({passed:false,stage,message:error instanceof assert.AssertionError?
  `assertion_failed:${error.message.slice(0,140)}`:error.message}));process.exitCode=1;}
finally {
  await closeFeed();
  if(id&&account){console.log(JSON.stringify({cleanupRequired:{roomId:id,uid:account.localId}}));
    if((await input.question('Install exact-fixture cleanup; type CLEANUP: ')).trim()==='CLEANUP'){
      try{const result=await api('cleanupFlowFixture',{roomId:id});assert.equal(result.data.guestDeleted,true);console.log(JSON.stringify({cleanupPassed:true}));}
      catch{console.error(JSON.stringify({cleanupFailed:true,roomId:id,uid:account.localId}));process.exitCode=1;}
    }
  }else if(account){const deleted=await json(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${key}`,{idToken:account.idToken});
    console.log(JSON.stringify({guestDeleted:deleted.status===200,profileCleanupRequired:account.localId}));}
  input.close();
}
