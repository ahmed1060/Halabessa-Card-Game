// Manual production smoke test; NEVER run automatically in CI.
// Creates only a private QA room/new anonymous accounts. Tokens stay in memory.
// Afterwards expire/remove its Firebase state and delete the temporary accounts.
// The printed fixture IDs allow a separately verified SQL-only cleanup.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';

if (!process.argv.includes('--live')) throw new Error('Explicit --live flag required');
const options = readFileSync('lib/firebase_options.dart', 'utf8');
const apiKey = /FirebaseOptions web = FirebaseOptions\(\s*apiKey: '([^']+)'/.exec(options)?.[1];
if (!apiKey || !options.includes("projectId: 'halabessa-card-game1'")) throw new Error('Unexpected Firebase project');
const edge = 'https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api';
const database = 'https://halabessa-card-game1-default-rtdb.firebaseio.com';
const accounts = [];
let roomId;
let stage = 'initialization';
async function request(url, method, body, token) {
  try {
    const response = await fetch(url, { method, signal: AbortSignal.timeout(20_000),
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
    return { status: response.status, data: await response.json() };
  } catch { throw new Error(`transport_failed_at_${stage}`); } // Never print token-bearing URLs.
}
async function api(account, action, data = {}, allowRejected = false) {
  const result = await request(edge, 'POST', { action, ...data }, account.idToken);
  if (!allowRejected) assert.equal(result.status, 200, `${stage}: ${result.status}/${result.data.error ?? 'unknown'}`);
  return result;
}
function command(commandType, expectedVersion, commandPayload = {}) {
  return { roomId, commandType, expectedVersion, commandPayload, commandId: randomUUID() };
}
async function firebase(account, path, method, body) {
  const result = await request(`${database}/${path}.json?auth=${encodeURIComponent(account.idToken)}`, method, body);
  assert.equal(result.status, 200, `${stage}: Firebase ${result.status}`);
  return result.data;
}
try {
  stage = 'guest accounts';
  for (let index = 0; index < 4; index++) {
    const signed = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
      'POST', { returnSecureToken: true });
    assert.equal(signed.status, 200, `guest creation ${signed.status}`);
    accounts.push({ uid: signed.data.localId, idToken: signed.data.idToken });
  }
  stage = 'private room';
  const created = await api(accounts[0], 'createRoom', { mode: 'classic', maxPoints: 21,
    timerDurationSeconds: 15, isPublic: false, displayName: 'CodexDeliveryQA_0', cardBackId: 'default_card', avatarUrl: '' });
  roomId = created.data.roomId;
  assert.ok(/^[A-Z]{3}\d{5}$/.test(roomId));
  for (let index = 1; index < 4; index++) {
    await api(accounts[index], 'joinRoom', { roomId, displayName: `CodexDeliveryQA_${index}`,
      cardBackId: 'default_card', avatarUrl: '' });
  }
  const initial = (await api(accounts[0], 'getMatchSnapshot', { roomId })).data;
  assert.equal(initial.state.playerIds[2], accounts[1].uid);
  const seats = initial.state.playerIds.map(uid => accounts.find(account => account.uid === uid));
  stage = 'presence and chat';
  await firebase(accounts[0], `matches/${roomId}/presence`, 'PATCH', { [accounts[0].uid]: true });
  await firebase(accounts[0], `matches/${roomId}/chat/qa`, 'PUT', { id: 'qa', senderId: accounts[0].uid,
    senderName: 'QA', text: 'delivery preservation check', timestamp: Date.now(), isQuickChat: false });
  stage = 'start and idempotent retry';
  const start = command('startRound', initial.version);
  const started = (await api(accounts[0], 'submitMatchCommand', start)).data;
  assert.equal(started.version, 1); assert.equal(started.mirrorPending, false);
  const retry = (await api(accounts[0], 'submitMatchCommand', start)).data;
  assert.equal(retry.duplicate, true); assert.equal(retry.version, 1);
  await api(seats[3], 'submitMatchCommand', command('cut', 1, { position: 20 }));
  await api(seats[0], 'submitMatchCommand', command('dealInitial', 2));
  await api(seats[0], 'submitMatchCommand', command('beginPlay', 3));
  stage = 'simultaneous plays';
  const turn = (await api(seats[1], 'getMatchSnapshot', { roomId })).data;
  assert.equal(turn.version, 4); assert.equal(turn.hand.length, 4);
  assert.equal('handCards' in turn.state, false);
  const competing = turn.hand.slice(0, 2).map(card => command('playCard', 4, { card }));
  const responses = await Promise.all(competing.map(intent => api(seats[1], 'submitMatchCommand', intent, true)));
  assert.equal(responses.filter(result => result.status === 200).length, 1);
  assert.equal(responses.filter(result => result.status === 409 && result.data.error === 'version_conflict').length, 1);
  const acceptedIndex = responses.findIndex(result => result.status === 200);
  const after = (await api(seats[1], 'getMatchSnapshot', { roomId })).data;
  assert.equal(after.version, 5); assert.equal(after.hand.length, 3);
  stage = 'retry after a later turn';
  const next = (await api(seats[2], 'getMatchSnapshot', { roomId })).data;
  await api(seats[2], 'submitMatchCommand', command('playCard', 5, { card: next.hand[0] }));
  const lateRetry = (await api(seats[1], 'submitMatchCommand', competing[acceptedIndex])).data;
  assert.equal(lateRetry.duplicate, true); assert.equal(lateRetry.version, 6);
  assert.equal(lateRetry.appliedVersion, 5); assert.equal(lateRetry.hand.length, 3);
  const mirrored = await firebase(accounts[0], `matches/${roomId}`, 'GET');
  assert.equal(mirrored.serverVersion, 6);
  assert.equal(mirrored.presence[accounts[0].uid], true);
  assert.equal(mirrored.chat.qa.text, 'delivery preservation check');
  console.log(JSON.stringify({ passed: true, simultaneousAccepted: 1, simultaneousRejected: 1,
    latestRetryVersion: 6, chatAndPresencePreserved: true }));
} catch (error) {
  console.error(JSON.stringify({ passed: false, stage, message: error.message }));
  process.exitCode = 1;
} finally {
  stage = 'fixture cleanup';
  let firebaseCleaned = !roomId;
  if (roomId && accounts[0]) {
    try {
      await firebase(accounts[0], `matches/${roomId}/expireAt`, 'PUT', new Date(Date.now() - 1000).toISOString());
      await api(accounts[0], 'refreshRoomIndex', { roomId });
      await firebase(accounts[0], '', 'PATCH', { [`matches/${roomId}`]: null, [`matchHands/${roomId}`]: null });
      firebaseCleaned = true;
    } catch { /* Report fixture ID for scoped cleanup; never delete another room. */ }
  }
  let accountsDeleted = 0;
  for (const account of accounts) {
    try {
      const deleted = await request(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${apiKey}`,
        'POST', { idToken: account.idToken });
      if (deleted.status === 200) accountsDeleted++;
    } catch { /* Keep cleanup failure visible without exposing credentials. */ }
  }
  console.log(JSON.stringify({ fixture: { roomId, users: accounts.map(account => account.uid),
    firebaseCleaned, accountsDeleted, sqlCleanupRequired: true } }));
}
