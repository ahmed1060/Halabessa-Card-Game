import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, collection, setDoc, updateDoc, writeBatch, Timestamp, deleteField } from 'firebase/firestore';

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
test('deletion block rejects old-token reads, profile recreation and reservation writes', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/blocked'), {displayName:'Private'});
    await setDoc(doc(context.firestore(), 'accountDeletionBlocked/blocked'), {blocked:true});
    await setDoc(doc(context.firestore(), 'accountDeletionBlocked/blocked-admin'), {blocked:true});
  });
  const db = env.authenticatedContext('blocked').firestore();
  await assertFails(getDoc(doc(db,'users/blocked')));
  await assertFails(setDoc(doc(db,'users/blocked'),{displayName:'Recreated'}));
  await assertFails(setDoc(doc(db,'usernames/recreated'),{uid:'blocked'}));
  await assertFails(setDoc(doc(db,'accountDeletionBlocked/blocked'),{blocked:false}));
  await assertFails(getDoc(doc(db,'accountDeletionBlocked/blocked')));
  const admin = env.authenticatedContext('blocked-admin',{admin:true}).firestore();
  await assertFails(getDoc(doc(admin,'users/blocked')));
  await assertSucceeds(setDoc(doc(env.authenticatedContext('unrelated').firestore(),'users/unrelated'),{displayName:'Still active'}));
});
before(async () => { env = await initializeTestEnvironment({
  projectId: 'demo-halabessa-ui', firestore: { rules },
}); });
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { await env?.cleanup(); });

test('private profiles and emails are readable only by their owner or a verified admin', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/owner'), { email: 'private@example.test', displayName: 'Public name' });
  });
  await assertSucceeds(getDoc(doc(env.authenticatedContext('owner').firestore(), 'users/owner')));
  await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(), 'users/owner')));
  await assertFails(getDocs(collection(env.authenticatedContext('other').firestore(), 'users')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/owner')));
  await assertSucceeds(getDocs(collection(env.authenticatedContext('admin', {admin: true}).firestore(), 'users')));
});

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


test('birth dates are private, date-only, 13+ and cannot erase unrelated profile fields', async () => {
  const owner = env.authenticatedContext('birthday-owner').firestore();
  const profile = doc(owner, 'users/birthday-owner');
  await assertSucceeds(setDoc(profile, {displayName: 'Owner', points: 27}));
  const date = Timestamp.fromDate(new Date('2000-02-29T00:00:00.000Z'));
  await assertSucceeds(updateDoc(profile, {dateOfBirth: date}));
  const saved = (await getDoc(profile)).data();
  assert.equal(saved.dateOfBirth.toMillis(), date.toMillis());
  assert.equal(saved.points, 27);
  assert.equal(saved.displayName, 'Owner');
  await assertFails(getDoc(doc(env.authenticatedContext('birthday-other').firestore(), 'users/birthday-owner')));
  await assertFails(updateDoc(doc(env.authenticatedContext('birthday-other').firestore(), 'users/birthday-owner'), {dateOfBirth: date}));
  for (const value of ['2000-02-29', Timestamp.fromMillis(Date.now() + 86400000),
    Timestamp.fromDate(new Date('2000-02-29T10:00:00.000Z')), Timestamp.fromDate(new Date('1899-01-01T00:00:00.000Z'))]) {
    await assertFails(updateDoc(profile, {dateOfBirth: value}));
  }
  const now = new Date();
  const thirteen = Timestamp.fromDate(new Date(Date.UTC(now.getUTCFullYear()-13, now.getUTCMonth(), now.getUTCDate())));
  const twelve = Timestamp.fromDate(new Date(Date.UTC(now.getUTCFullYear()-12, now.getUTCMonth(), now.getUTCDate())));
  await assertSucceeds(updateDoc(profile, {dateOfBirth: thirteen}));
  await assertFails(updateDoc(profile, {dateOfBirth: twelve}));
  await assertFails(updateDoc(profile, {dateOfBirth: deleteField()}));
  await assertSucceeds(updateDoc(profile, {displayName: 'Still editable'}));
});
