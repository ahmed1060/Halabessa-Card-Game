import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

// Never run these tests against a real project or an arbitrary remote host.
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
const rules = await readFile(new URL('../firestore.rules', import.meta.url), 'utf8');
test('weekly ranking cannot be created, forged or erased by its profile owner', async () => {
  const db = env.authenticatedContext('guest').firestore();
  await assertFails(setDoc(doc(db, 'users/guest'), {weeklyRanking: {week: '2026-10-05', points: 999}}));
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/guest'), {displayName: 'Guest', weeklyRanking: {week: '2026-10-05', points: 50}});
  });
  await assertFails(updateDoc(doc(db, 'users/guest'), {'weeklyRanking.points': 999}));
  await assertFails(setDoc(doc(db, 'users/guest'), {displayName: 'Guest'}));
  await assertSucceeds(updateDoc(doc(db, 'users/guest'), {displayName: 'New name'}));
});
let env;
before(async () => { env = await initializeTestEnvironment({
  projectId: 'demo-halabessa-ui', firestore: { rules },
}); });
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { await env?.cleanup(); });

test('original missing-isAdmin rule reproduces the rejected profile update', async () => {
  const original = await initializeTestEnvironment({ projectId: 'demo-halabessa-legacy', firestore: {
    rules: rules.replace("request.resource.data.get('isAdmin', false) == resource.data.get('isAdmin', false)",
      "request.resource.data.isAdmin == resource.data.get('isAdmin', false)"),
  }});
  try {
    const db = original.authenticatedContext('legacy').firestore();
    await assertSucceeds(setDoc(doc(db, 'users/legacy'), { displayName: 'Guest' }));
    await assertFails(updateDoc(doc(db, 'users/legacy'), { username: 'legacy_guest' }));
  } finally { await original.cleanup(); }
});

test('a profile without isAdmin saves the username and reservation together', async () => {
  const db = env.authenticatedContext('guest').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/guest'), { displayName: 'Guest' }));
  const batch = writeBatch(db);
  batch.set(doc(db, 'usernames/guest_name'), { uid: 'guest' });
  batch.update(doc(db, 'users/guest'), { username: 'guest_name', searchName: 'guest_name' });
  await assertSucceeds(batch.commit());
  assert.equal((await getDoc(doc(db, 'users/guest'))).data().username, 'guest_name');
});

test('missing or false admin fields cannot be promoted by the owner', async () => {
  const db = env.authenticatedContext('guest').firestore();
  await setDoc(doc(db, 'users/guest'), { displayName: 'Guest' });
  await assertFails(updateDoc(doc(db, 'users/guest'), { isAdmin: true }));
  await assertSucceeds(updateDoc(doc(db, 'users/guest'), { isAdmin: false }));
  await assertFails(updateDoc(doc(db, 'users/guest'), { isAdmin: true }));
  await assertFails(updateDoc(doc(db, 'users/guest'), { friends: ['other'] }));
});

test('failed profile writes do not leave a username reservation behind', async () => {
  const db = env.authenticatedContext('guest').firestore();
  await setDoc(doc(db, 'users/guest'), { displayName: 'Guest' });
  const batch = writeBatch(db);
  batch.set(doc(db, 'usernames/not_saved'), { uid: 'guest' });
  batch.update(doc(db, 'users/guest'), { username: 'not_saved', isAdmin: true });
  await assertFails(batch.commit());
  assert.equal((await getDoc(doc(db, 'usernames/not_saved'))).exists(), false);
});

test('another player cannot take a reserved name or edit the profile', async () => {
  const owner = env.authenticatedContext('owner').firestore();
  const other = env.authenticatedContext('other').firestore();
  await setDoc(doc(owner, 'users/owner'), { displayName: 'Owner' });
  await setDoc(doc(owner, 'usernames/owned_name'), { uid: 'owner' });
  await assertFails(setDoc(doc(other, 'usernames/owned_name'), { uid: 'other' }));
  await assertFails(updateDoc(doc(other, 'users/owner'), { username: 'changed' }));
});
