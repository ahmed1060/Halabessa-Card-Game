import assert from 'node:assert/strict';
import test from 'node:test';
import { publicProfile, createPublicProfileStore } from '../../supabase/functions/halabessa-api/public_profiles.ts';
const document = { name: 'projects/qa/databases/(default)/documents/users/alice', fields: {
  displayName: {stringValue: 'Alice'}, points: {integerValue: '50'}, email: {stringValue: 'private@example.test'},
  coins: {integerValue: '900'}, inventory: {mapValue: {fields: {secret: {integerValue: '1'}}}},
  friends: {stringValue: 'private'}, isAdmin: {booleanValue: true},
  weeklyRanking: {mapValue: {fields: {week: {stringValue: '2026-10-05'}, points: {integerValue: '50'}, email: {stringValue: 'private'}}}},
}};
test('public view allowlists fields and rejects nested private ranking fields', () => {
  assert.deepEqual(publicProfile(document), {uid: 'alice', displayName: 'Alice', points: 50, weeklyRanking: {week: '2026-10-05', points: 50}});
});

test('public scalar fields never expose nested objects or non-finite numbers', () => {
  assert.deepEqual(publicProfile({name: document.name, fields: {
    displayName: {mapValue: {fields: {email: {stringValue: 'private'}}}},
    points: {integerValue: 'Infinity'}, wins: {integerValue: '1.2'},
    weeklyRanking: {mapValue: {fields: {week: {integerValue: '123'}}}},
  }}), {uid: 'alice', displayName: null, points: null, wins: null, weeklyRanking: {week: null}});
});
test('server projection remains private even if upstream returns full documents', async () => {
  const calls: {url: string; body?: any}[] = [];
  const store = createPublicProfileStore('qa', async () => 'server-secret', async (url, init) => {
    calls.push({url: String(url), body: init?.body ? JSON.parse(String(init.body)) : null});
    return Response.json(String(url).endsWith(':runQuery') ? [{document}] : document);
  });
  const result = await store.query({category: 'points', week: '2026-10-05'});
  assert.equal(JSON.stringify(result).includes('private'), false);
  assert.equal(calls[0].body.structuredQuery.limit, 50);
  assert.equal(calls[0].body.structuredQuery.orderBy[0].field.fieldPath, 'weeklyRanking.points');
  assert.equal(calls[0].body.structuredQuery.select.fields.some((field: any) => field.fieldPath === 'email'), false);
  assert.equal((await store.get('alice'))?.uid, 'alice');
  await assert.rejects(store.get('../bob'), /invalid_profile_query/);
  await assert.rejects(store.query({category: 'email'}), /invalid_profile_query/);
  assert.deepEqual(await store.query({search: 'a'}), []);
});
test('missing profiles and transport failures cannot produce fabricated users', async () => {
  const store = createPublicProfileStore('qa', async () => 'server-secret', async () => new Response('{}', {status: 404}));
  assert.equal(await store.get('alice'), null);
  await assert.rejects(store.query({category: 'wins'}), /public_profiles_unavailable/);
});
