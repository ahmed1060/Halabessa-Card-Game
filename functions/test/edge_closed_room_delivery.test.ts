import test from 'node:test';
import assert from 'node:assert/strict';
import {deliverClosedRoom} from '../../supabase/functions/halabessa-api/closed_room_delivery.ts';
import type {PublicationRunner} from '../../supabase/functions/halabessa-api/room_publication.ts';

function fixture(pending=true) {
  let sockets=0, reads=0, updates=0, settlements=0, erased=0;
  let failSettle=false,failErase=false,present=true;
  const room={state:{protocolVersion:1,roomClosed:true,settlementPending:pending},version:7,hands:{}};
  const run:PublicationRunner=async work=>{
    sockets++;
    try{return await work(async(sql,args)=>{
      assert.equal(args[0],'ABC12345');
      if(sql.startsWith('select')){reads++;return present?[{created_at:'1791813600'}]:[];}
      updates++;assert.match(sql,/version=\$2/);assert.equal(args[1],7);
      assert.match(sql,/settlementPending.*true/s);return [];
    });}finally{sockets--;}
  };
  const settle=async()=>{assert.equal(sockets,0);settlements++;if(failSettle)throw Error('reward_unavailable');return 'receipt-stable';};
  const erase=async()=>{assert.equal(sockets,0);erased++;if(failErase)throw Error('mirror_unavailable');};
  return {room,run,settle,erase,counts:()=>({reads,updates,settlements,erased}),
    setSettleFailure:(value:boolean)=>{failSettle=value;},setEraseFailure:(value:boolean)=>{failErase=value;},missing:()=>{present=false;}};
}
test('pending rewards settle before deletion without holding a socket',async()=>{
  const f=fixture();await deliverClosedRoom(f.run,'ABC12345',f.room,f.settle,f.erase);
  assert.deepEqual(f.counts(),{reads:1,updates:1,settlements:1,erased:1});
});
test('reward failure leaves mirrors intact and is retryable',async()=>{
  const f=fixture();f.setSettleFailure(true);
  await assert.rejects(deliverClosedRoom(f.run,'ABC12345',f.room,f.settle,f.erase),/reward_unavailable/);
  assert.equal(f.counts().erased,0);assert.equal(f.counts().updates,0);
  f.setSettleFailure(false);await deliverClosedRoom(f.run,'ABC12345',f.room,f.settle,f.erase);
  assert.equal(f.counts().erased,1);
});
test('failed deletion is retryable and completed settlement does not repeat',async()=>{
  const f=fixture(false);f.setEraseFailure(true);
  await assert.rejects(deliverClosedRoom(f.run,'ABC12345',f.room,f.settle,f.erase),/mirror_unavailable/);
  f.setEraseFailure(false);await deliverClosedRoom(f.run,'ABC12345',f.room,f.settle,f.erase);
  assert.deepEqual(f.counts(),{reads:0,updates:0,settlements:0,erased:2});
});
test('already purged pending snapshot has no further side effects',async()=>{
  const f=fixture();f.missing();await deliverClosedRoom(f.run,'ABC12345',f.room,f.settle,f.erase);
  assert.deepEqual(f.counts(),{reads:1,updates:0,settlements:0,erased:0});
});
test('invalid or occupied targets fail before any I/O',async()=>{
  const f=fixture();
  await assert.rejects(deliverClosedRoom(f.run,'*',f.room,f.settle,f.erase),/invalid_room_id/);
  await assert.rejects(deliverClosedRoom(f.run,'ABC12345',{...f.room,state:{roomClosed:false}},f.settle,f.erase),/room_not_closed/);
  assert.deepEqual(f.counts(),{reads:0,updates:0,settlements:0,erased:0});
});
