import test from 'node:test';
import assert from 'node:assert/strict';
import {runDeletionWorker} from '../../supabase/functions/halabessa-api/deletion_worker.ts';
import {deletionStages} from '../../supabase/functions/halabessa-api/account_deletion.ts';
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
function fixture() {
  const job={id,firebase_uid:'qa-only',completed_stages:[] as string[],status:'pending'};
  const items=new Map<string,{kind:string,item:string,processed:boolean}>();
  const effects:string[]=[];
  let denied=false,age=300;
  const query=async(sql:string,args:unknown[])=>{
    if(sql.includes('for update nowait'))return [{id}];
    if(sql.startsWith('select firebase_uid,completed_stages'))return [structuredClone(job)];
    if(sql.startsWith('select id::text, firebase_uid'))return [structuredClone(job)];
    if(sql.startsWith('update halabessa.account_deletion_jobs set completed_stages')) {job.completed_stages.push(String(args[1]));return [{id}];}
    if(sql.includes("set status='complete'")){job.status='complete';return [{id}];}
    if(sql.startsWith('insert into halabessa.account_deletion_inventory')) {
      for(const item of JSON.parse(String(args[2])))items.set(`${args[1]}:${item}`,{kind:String(args[1]),item,processed:false});return [];
    }
    if(sql.startsWith('update halabessa.account_deletion_inventory')){items.get(`${args[1]}:${args[2]}`)!.processed=true;return [];}
    if(sql.includes("kind='scan'"))return items.has(`scan:${args[1]}`)?[{exists:true}]:[];
    if(sql.startsWith('select item'))return [...items.values()].filter(r=>!r.processed && sql.includes(`kind='${r.kind}'`)).slice(0,5);
    if(sql.startsWith('select extract(epoch'))return [{age:String(age)}];
    if(sql.startsWith('delete from halabessa.user_profiles'))effects.push('SQL profile');
    return [];
  };
  const deps={project:'qa-project',databaseUrl:'https://qa.firebaseio.com',storageUrl:'https://qa.supabase.co',storageKey:'server-only',
    token:async()=>'server-only',settle:async()=>{throw new Error('no room should settle');},publish:async()=>{throw new Error('no room should publish');},
    fetcher:async(input:any,init:any)=>{
      const url=new URL(String(input));
      if(denied)return new Response('{}',{status:503});
      if(url.hostname==='identitytoolkit.googleapis.com'){effects.push(url.pathname.endsWith(':delete')?'Auth delete':'Auth block');return Response.json({});}
      if(url.hostname==='firestore.googleapis.com') {
        if(url.pathname.endsWith(':runQuery'))return Response.json([]);
        if(init.method==='GET')return new Response('{}',{status:404});
        effects.push('Firestore write');return Response.json({});
      }
      if(url.hostname==='qa.supabase.co'){effects.push('Avatar removal');return Response.json([]);}
      if(init.method!=='GET')effects.push('RTDB write');
      return Response.json(null);
    },
  };
  return {job,effects,query,deps,items,deny:(value:boolean)=>{denied=value;},age:(value:number)=>{age=value;}};
}
test('production adapters progress durably without the deleted session; Auth deletion is last',async()=>{
  const f=fixture();
  for(let i=0;i<20 && f.job.status!=='complete';i++)await runDeletionWorker(f.query,id,f.deps);
  assert.equal(f.job.status,'complete');assert.deepEqual(f.job.completed_stages,[...deletionStages]);
  assert.equal(f.effects.at(-1),'Auth delete');
  assert.ok(f.effects.indexOf('SQL profile')<f.effects.indexOf('Avatar removal'));
  assert.ok(f.effects.indexOf('Avatar removal')<f.effects.indexOf('Auth delete'));
});
test('upstream outage stays pending without removing profile or identity and resumes safely',async()=>{
  const f=fixture();f.deny(true);
  assert.deepEqual(await runDeletionWorker(f.query,id,f.deps),{status:'pending'});
  assert.equal(f.effects.length,0);assert.equal(f.job.completed_stages.length,0);
  f.deny(false);await runDeletionWorker(f.query,id,f.deps);
  assert.deepEqual(f.job.completed_stages,['blockSessions']);
  assert.equal(f.effects.includes('Auth delete'),false);
});
test('late-upload drain cannot be bypassed before avatar removal and final identity deletion',async()=>{
  const f=fixture();f.job.completed_stages.push(...deletionStages.slice(0,4));f.age(30);
  await runDeletionWorker(f.query,id,f.deps);assert.equal(f.effects.length,0);assert.equal(f.job.status,'pending');
  f.age(120);await runDeletionWorker(f.query,id,f.deps);assert.deepEqual(f.effects,['Avatar removal']);
  await runDeletionWorker(f.query,id,f.deps);assert.equal(f.job.status,'complete');
});

test('room inventory is drained in bounded batches without prematurely completing its stage',async()=>{
  const f=fixture();f.job.completed_stages.push(...deletionStages.slice(0,2));
  for(const root of ['users','matches','matchChat'])f.items.set(`scan:${root}`,{kind:'scan',item:root,processed:true});
  for(let i=0;i<12;i++)f.items.set(`room:ABC${10000+i}`,{kind:'room',item:`ABC${10000+i}`,processed:false});
  const processed=()=>[...f.items.values()].filter(row=>row.kind==='room' && row.processed).length;
  for(const expected of [5,10,12]) {
    assert.deepEqual(await runDeletionWorker(f.query,id,f.deps),{status:'pending'});
    assert.equal(processed(),expected);assert.equal(f.job.completed_stages.length,2);
  }
  await runDeletionWorker(f.query,id,f.deps);assert.equal(f.job.completed_stages.length,3);
  assert.equal(f.effects.includes('Auth delete'),false);
});
