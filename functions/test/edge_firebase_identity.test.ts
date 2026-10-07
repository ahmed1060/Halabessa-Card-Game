import assert from 'node:assert/strict';
import test from 'node:test';
import {assertActiveIdentity, createFirebaseIdentityStore} from '../../supabase/functions/halabessa-api/firebase_identity.ts';

const uid = 'isolated-qa-only';
function fixture(row: any = {localId: uid}, status = 200) {
  const calls: any[] = [];
  const store = createFirebaseIdentityStore('qa-project', async () => 'private-oauth-token', async (url, init) => {
    calls.push({url: String(url), body: JSON.parse(String(init?.body)), headers: init?.headers, signal: init?.signal});
    return Response.json(String(url).endsWith(':lookup') ? {users: row === null ? [] : [row]} : row, {status});
  });
  return {store, calls};
}
test('lookup is scoped to exactly one UID and only returns minimized identity fields', async () => {
  const f = fixture({localId: uid, email: 'qa@example.test', passwordHash: 'secret-hash', customAttributes: '{"admin":true,"private":"secret"}', providerUserInfo: [{providerId: 'password'}], validSince: '100'});
  assert.deepEqual(await f.store.lookup(uid), {uid, email:'qa@example.test', disabled:false, validSince:100, verifiedGuest:false, admin:true, providers:['password']});
  assert.deepEqual(f.calls[0].body, {localId:[uid], targetProjectId:'qa-project'});
  assert.equal(f.calls[0].url, 'https://identitytoolkit.googleapis.com/v1/accounts:lookup');
  assert.ok(f.calls[0].signal instanceof AbortSignal);
});
test('only live credentialless accounts qualify as guests', async () => {
  assert.equal((await fixture().store.lookup(uid))?.verifiedGuest, true);
  for (const fields of [{email:'qa@example.test'}, {phoneNumber:'+10000000000'}, {passwordHash:'hash'}, {providerUserInfo:[{providerId:'google.com'}]}]) {
    assert.equal((await fixture({localId:uid, ...fields}).store.lookup(uid))?.verifiedGuest, false);
  }
});
test('malformed or mismatched identities fail closed', async () => {
  for (const fields of [{localId:'someone-else'}, {validSince:'1e3'}, {validSince:'9007199254740992'}, {providerUserInfo:null}, {providerUserInfo:'google'}, {providerUserInfo:[{}]}, {disabled:'false'}, {email:{}}, {customAttributes:'[]'}]) {
    await assert.rejects(fixture({localId:uid, ...fields}).store.lookup(uid), /invalid_identity_response/);
  }
});
test('absent, disabled and revoked sessions fail; refreshed issued-at cannot replace auth-time', async () => {
  assert.equal(await fixture(null).store.lookup(uid), null);
  const account = (await fixture({localId:uid, validSince:'100'}).store.lookup(uid))!;
  assertActiveIdentity(account, 100);
  for (const time of [99, null, '100', NaN, Infinity, -1]) assert.throws(() => assertActiveIdentity(account, time), /unauthenticated/);
  assert.throws(() => assertActiveIdentity(null, 100), /unauthenticated/);
  assert.throws(() => assertActiveIdentity({...account, disabled:true}, 100), /unauthenticated/);
});
test('revocation disables the single account; deletion never uses a user ID token', async () => {
  const f = fixture({});
  await f.store.disableAndRevoke(uid, 100);
  await f.store.deleteIdentity(uid);
  assert.deepEqual(f.calls.map(call => call.body), [{localId:uid, disableUser:true, validSince:'100', targetProjectId:'qa-project'}, {localId:uid, targetProjectId:'qa-project'}]);
  assert.equal(f.calls[1].url.endsWith(':delete'), true);
  assert.equal(f.calls[0].headers.Authorization, 'Bearer private-oauth-token');
});
test('invalid targets and revocation times never make network calls', async () => {
  const f = fixture();
  for (const target of ['', '../other', 'other/uid', 'bad\nuid', 'a'.repeat(129)]) await assert.rejects(f.store.deleteIdentity(target), /invalid_identity_uid/);
  for (const time of [NaN, -1, 0.5]) await assert.rejects(f.store.disableAndRevoke(uid, time), /invalid_revocation_time/);
  assert.equal(f.calls.length, 0);
});
test('only explicit missing-user errors are idempotent; permission failures remain failures', async () => {
  const missing = fixture({error:{message:'USER_NOT_FOUND'}}, 400);
  await missing.store.disableAndRevoke(uid, 100);
  await missing.store.deleteIdentity(uid);
  for (const status of [403, 429, 500]) {
    const f = fixture({error:{message:'private upstream details'}}, status);
    await assert.rejects(f.store.deleteIdentity(uid), {message:'identity_request_failed'});
  }
});
test('upstream errors and malformed responses never leak token or response text', async () => {
  const store = createFirebaseIdentityStore('qa-project', async () => 'secret', async () => {throw new Error('private-token');});
  await assert.rejects(store.lookup(uid), {message:'identity_service_unavailable'});
  const bad = createFirebaseIdentityStore('qa-project', async () => 'secret', async () => new Response('private-html'));
  await assert.rejects(bad.lookup(uid), {message:'invalid_identity_response'});
});
