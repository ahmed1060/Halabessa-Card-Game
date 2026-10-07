import test from 'node:test';
import assert from 'node:assert/strict';
import {assertNotDeletionBlocked} from '../../supabase/functions/halabessa-api/deletion_access.ts';
test('an absent block permits an active account and uses only its encoded UID',async()=>{
  await assertNotDeletionBlocked('qa-only',async path=>{
    assert.equal(path,'accountDeletionBlocked/qa-only');return {status:200,data:null};
  });
});
test('every existing block including false is denied; transport errors fail closed',async()=>{
  for(const data of [true,false,{},0,'blocked'])await assert.rejects(assertNotDeletionBlocked('qa',async()=>({status:200,data})),/unauthenticated/);
  for(const status of [403,500])await assert.rejects(assertNotDeletionBlocked('qa',async()=>({status,data:null})),/account_guard_unavailable/);
});
