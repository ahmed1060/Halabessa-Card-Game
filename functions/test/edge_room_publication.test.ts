import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { commitAndQueue, earlyAckEnabled, publicationLease, publishRoom, retryPublicationLater,
  type PublicationQuery } from '../../supabase/functions/halabessa-api/room_publication.ts';

function fixture({busy=false, version='4', invalid=false}={}) {
  const calls: {sql:string,args:unknown[]}[]=[];
  const query: PublicationQuery=async(sql,args)=>{
    calls.push({sql,args});
    if(sql.includes('pg_try_advisory'))return [{acquired:!busy}];
    if(sql.includes('join halabessa.room_secrets'))return [{
      version, state:{id:'ABC12345',protocolVersion:invalid?0:1,playerIds:['human']},
      hands:{human:[]},
    }];
    return [];
  };
  return {query,calls};
}

test('early acknowledgment canary is scoped to one room and fails closed',()=>{
  const config={async_ack_enabled:false,canary_room_id:'ABC12345'};
  assert.equal(earlyAckEnabled(config,'ABC12345'),true);
  assert.equal(earlyAckEnabled(config,'XYZ67890'),false);
  assert.equal(earlyAckEnabled(undefined,'ABC12345'),false);
  assert.equal(earlyAckEnabled({async_ack_enabled:'true'},'ABC12345'),false);
  assert.equal(earlyAckEnabled({async_ack_enabled:true},'ABC12345'),true);
  assert.equal(earlyAckEnabled({async_ack_enabled:true},'../other'),false);
});

test('publication holds a transaction-scoped lease through mirror and intent removal',async()=>{
  const {query,calls}=fixture();
  const result=await publishRoom(query,'ABC12345',async room=>{
    assert.equal(room.version,4);
    assert.equal(calls[0].sql,'begin');
    assert.match(calls[1].sql,/pg_try_advisory_xact_lock/);
    assert.match(calls[2].sql,/for update of r,s/);
    assert.equal(calls.some(c=>c.sql==='commit'),false);
  });
  assert.equal(result?.version,4);
  assert.match(calls.at(-2)!.sql,/version<=\$2/);
  assert.deepEqual(calls.at(-2)!.args,['ABC12345',4]);
  assert.equal(calls.at(-1)!.sql,'commit');
});

test('async publisher does not lock gameplay rows; newer intents survive its snapshot',async()=>{
  const {query,calls}=fixture();
  const pending=new Set([3,4]);
  await publishRoom(async(sql,args)=>{
    const rows=await query(sql,args);
    if(sql.startsWith('delete from'))for(const version of pending){
      if(version<=Number(args[1]))pending.delete(version);
    }
    return rows;
  },'ABC12345',async()=>{pending.add(5);},false);
  assert.equal(calls[2].sql.includes('for update'),false);
  assert.deepEqual([...pending],[5]);
});

test('busy publisher does not read or erase a pending revision',async()=>{
  const {query,calls}=fixture({busy:true});
  assert.equal(await publishRoom(query,'ABC12345',async()=>assert.fail('no publish')),null);
  assert.equal(calls.length,3);
  assert.equal(calls.at(-1)!.sql,'rollback');
});

test('competing publishers cannot rewind delivery while commands commit newer revisions',async()=>{
  let leased=false,version=4;
  const intents=new Set([4]);
  const delivered:number[]=[];
  let release!:()=>void;
  const blocked=new Promise<void>(resolve=>{release=resolve;});
  function connection():PublicationQuery {
    let acquired=false;
    return async(sql,args)=>{
      if(sql.includes('pg_try_advisory')) {
        acquired=!leased;if(acquired)leased=true;
        return [{acquired}];
      }
      if(sql.includes('join halabessa.room_secrets'))return [{
        version:String(version),state:{id:'ABC12345',protocolVersion:1},hands:{human:[]},
      }];
      if(sql.startsWith('delete from'))for(const v of intents)if(v<=Number(args[1]))intents.delete(v);
      if((sql==='commit'||sql==='rollback')&&acquired){leased=false;acquired=false;}
      return [];
    };
  }
  let entered!:()=>void;
  const mirrorStarted=new Promise<void>(resolve=>{entered=resolve;});
  const first=publishRoom(connection(),'ABC12345',async room=>{
    entered();await blocked;delivered.push(room.version);
  },false);
  await mirrorStarted;
  version=5;intents.add(5); // Writers never need the publication lease.
  assert.equal(await publishRoom(connection(),'ABC12345',async()=>assert.fail(),false),null);
  release();await first;
  assert.deepEqual([...intents],[5]);
  await publishRoom(connection(),'ABC12345',async room=>{delivered.push(room.version);},false);
  assert.deepEqual(delivered,[4,5]);
  assert.equal(intents.size,0);assert.equal(leased,false);
});

test('mirror failure rolls back without deleting durable intents',async()=>{
  const {query,calls}=fixture();
  await assert.rejects(publishRoom(query,'ABC12345',async()=>{throw Error('transport');}),/transport/);
  assert.equal(calls.at(-1)!.sql,'rollback');
  assert.equal(calls.some(c=>c.sql.startsWith('delete from')),false);
});

test('invalid stored protocol/version fails closed before any mirror',async()=>{
  for(const options of [{invalid:true},{version:'9007199254740992'}]){
    const {query,calls}=fixture(options);
    await assert.rejects(publishRoom(query,'ABC12345',async()=>assert.fail()),/invalid_publication/);
    assert.equal(calls.at(-1)!.sql,'rollback');
  }
});

test('early acknowledgment follows commit and preserves work if scheduling fails',async()=>{
  const events:string[]=[];
  assert.deepEqual(await commitAndQueue(async()=>{events.push('commit');},()=>{
    events.push('schedule'); throw Error('runtime stopped');
  }),{snapshot:null,mirrorPending:true});
  assert.deepEqual(events,['commit','schedule']);
  await assert.rejects(commitAndQueue(async()=>{throw Error('commit failed');},()=>assert.fail()),/commit failed/);
});

test('deletion lease uses the same transaction namespace; malformed room IDs are rejected',async()=>{
  const {query,calls}=fixture();
  assert.equal(await publicationLease(query,'ABC12345',true),true);
  assert.match(calls[0].sql,/pg_advisory_xact_lock/);
  assert.deepEqual(calls[0].args,['halabessa-publication:ABC12345']);
  await assert.rejects(publicationLease(query,'../other'),/invalid_room_id/);
  await assert.rejects(retryPublicationLater(query,'../other'),/invalid_room_id/);
  await retryPublicationLater(query,'ABC12345');
  assert.match(calls.at(-1)!.sql,/attempts=attempts\+1/);
});

test('migration commits private intents with revisions and starts both rollout switches off',()=>{
  const sql=readFileSync(new URL('../../supabase/migrations/20261010205735_durable_match_publication.sql',import.meta.url),'utf8');
  assert.match(sql,/after insert or update of version/);
  assert.match(sql,/references halabessa.rooms\(room_id\) on delete cascade/);
  assert.match(sql,/security invoker set search_path = ''/);
  for(const table of ['room_publications','publication_worker_config']){
    assert.ok(sql.includes(`alter table halabessa.${table} enable row level security`));
    assert.ok(sql.includes(`revoke all on halabessa.${table} from public,anon,authenticated`));
  }
  assert.match(sql,/async_ack_enabled boolean not null default false/);
  assert.match(sql,/cron.alter_job\(cron.schedule/);
  assert.match(sql,/active := false/);
  assert.match(sql,/where exists\(select 1 from halabessa.room_publications where next_attempt_at<=now\(\)\)/);
  assert.match(sql,/halabessa_publication_worker/);
  assert.equal(sql.includes('halabessa_deletion_worker'),false);
});
