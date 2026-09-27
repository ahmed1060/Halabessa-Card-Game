// Run deliberately: makes a temporary Firebase guest and bounded requests to
// the deployed API. Tokens stay in memory. Deletes that guest in finally;
// reports its UID so its exact Supabase test profile can also be cleaned up.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const endpoint = 'https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api';
const origin = 'https://halabessa-card-game1.web.app';
const options = await readFile(new URL('../lib/firebase_options.dart', import.meta.url), 'utf8');
const apiKey = options.match(/FirebaseOptions web = FirebaseOptions\(\s*apiKey: '([^']+)'/)[1];

async function request(url, options = {}) {
  const response = await fetch(url, { ...options, signal: AbortSignal.timeout(30_000) });
  const text = await response.text();
  return { status: response.status, body: text ? JSON.parse(text) : null };
}

const startedAt = new Date().toISOString();
const statuses = {};
function check(result, expected) {
  statuses[result.status] = (statuses[result.status] ?? 0) + 1;
  assert.equal(result.status, expected, `Unexpected API status: ${JSON.stringify(result)}`);
}

// Cold-start/health traffic must not create database sessions.
for (let batch = 0; batch < 3; batch++) {
  const results = await Promise.all(Array.from({ length: 8 }, () => request(endpoint, { headers: { Origin: origin } })));
  for (const result of results) check(result, 200);
}
check(await request(endpoint, { method: 'OPTIONS', headers: { Origin: origin } }), 204);
check(await request(endpoint, { method: 'POST', headers: { Origin: origin, 'Content-Type': 'application/json' }, body: '{}' }), 401);

let guest;
try {
  const signup = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', Referer: origin },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  assert.equal(signup.status, 200, `Guest sign-in failed (${signup.status})`);
  guest = signup.body;
  const call = (action, data = {}) => request(endpoint, {
    method: 'POST',
    headers: { Origin: origin, 'Content-Type': 'application/json', Authorization: `Bearer ${guest.idToken}` },
    body: JSON.stringify({ action, ...data }),
  });
  check(await call('bootstrapProfile'), 200);
  for (let batch = 0; batch < 4; batch++) {
    const results = await Promise.all([
      call('getDailyRewardStatus'), call('getSocialGraph'), call('getAdminStatus'), call('getDailyRewardStatus'),
    ]);
    for (const result of results) check(result, 200);
  }
  check(await call('submitMatchCommand', { roomId: 'invalid' }), 400);
  check(await call('getDailyRewardStatus'), 200);
} finally {
  if (guest) {
    const deleted = await request(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${apiKey}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Referer: origin },
      body: JSON.stringify({ idToken: guest.idToken }),
    });
    console.log(JSON.stringify({ testProfileUid: guest.localId, firebaseGuestDeleted: deleted.status === 200 }));
  }
}
console.log(JSON.stringify({ startedAt, finishedAt: new Date().toISOString(), statuses, passed: true }));
