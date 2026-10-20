import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

// These role fixtures are permitted only in the isolated local demo emulator.
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
const rules = await readFile(new URL('../firestore.rules', import.meta.url), 'utf8');
const owner = { admin: true, email_verified: true, email: 'ahmed.hossam1060@gmail.com' };
let env;
before(async () => { env = await initializeTestEnvironment({
  projectId: 'demo-halabessa-orientation', firestore: { rules },
}); });
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { await env?.cleanup(); });
const policy = db => doc(db, 'settings/orientation');

test('verified primary admin may create and update only the boolean visibility policy', async () => {
  const db = env.authenticatedContext('primary', owner).firestore();
  await assertSucceeds(setDoc(policy(db), { showPlayerControl: true }));
  await assertSucceeds(updateDoc(policy(db), { showPlayerControl: false }));
  assert.equal((await getDoc(policy(db))).data().showPlayerControl, false);
  await assertFails(setDoc(policy(db), { showPlayerControl: 'false' }));
  await assertFails(setDoc(policy(db), {}));
  await assertFails(setDoc(policy(db), { showPlayerControl: true, extra: true }));
  await assertFails(deleteDoc(policy(db)));
});

for (const [role, claims] of Object.entries({
  player: {},
  delegated: { ...owner, email: 'delegated@example.test' },
  unverified: { ...owner, email_verified: false },
  missingVerification: { admin: true, email: owner.email },
  nonAdmin: { ...owner, admin: false },
  missingEmail: { admin: true, email_verified: true },
})) {
  test(`${role} cannot create, replace or update the orientation policy`, async () => {
    const db = env.authenticatedContext(role, claims).firestore();
    await assertFails(setDoc(policy(db), { showPlayerControl: true }));
    await env.withSecurityRulesDisabled(async c => {
      await setDoc(policy(c.firestore()), { showPlayerControl: true });
      await setDoc(doc(c.firestore(), `users/${role}`), { isAdmin: true });
    });
    await assertFails(setDoc(policy(db), { showPlayerControl: false }));
    await assertFails(updateDoc(policy(db), { showPlayerControl: false }));
    await assertFails(deleteDoc(policy(db)));
  });
}

test('anonymous and deletion-blocked primary-admin sessions cannot read or write policy', async () => {
  await env.withSecurityRulesDisabled(async c => {
    await setDoc(policy(c.firestore()), { showPlayerControl: false });
    await setDoc(doc(c.firestore(), 'accountDeletionBlocked/blocked-primary'), { blocked: true });
  });
  for (const db of [env.unauthenticatedContext().firestore(),
    env.authenticatedContext('blocked-primary', owner).firestore()]) {
    await assertFails(getDoc(policy(db)));
    await assertFails(setDoc(policy(db), { showPlayerControl: true }));
  }
  await assertSucceeds(getDoc(policy(env.authenticatedContext('player').firestore())));
});

test('the special restriction does not change existing general-settings admin policy', async () => {
  const delegated = env.authenticatedContext('delegated', { admin: true }).firestore();
  await assertSucceeds(setDoc(doc(delegated, 'settings/audio'), { enabled: true }));
  const player = env.authenticatedContext('player').firestore();
  await assertFails(setDoc(doc(player, 'settings/audio'), { enabled: false }));
});
