// Explicit, temporary production QA only. Requires the operator to install a
// short-lived cleanup action scoped to the printed NEW account and room IDs.
// Never leave that action deployed or run this script automatically in CI.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
if (!process.argv.includes('--live')) throw Error('Explicit --live flag required');
const options = readFileSync('lib/firebase_options.dart', 'utf8');
const apiKey = /FirebaseOptions web = FirebaseOptions\(\s*apiKey: '([^']+)'/.exec(options)?.[1];
if (!apiKey || !options.includes("projectId: 'halabessa-card-game1'")) throw Error('Unexpected project');
const edge = 'https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api';
const documents = 'https://firestore.googleapis.com/v1/projects/halabessa-card-game1/databases/(default)/documents';
const accounts = []; let roomId, state, stage = 'initialization', profilesCreated = false;
const wait = ms => new Promise(resolve => setTimeout(resolve, Math.max(0, ms)));
async function request(url, method, body, token) {
  try {
    const response = await fetch(url, { method, signal: AbortSignal.timeout(45000),
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      ...(body == null ? {} : { body: JSON.stringify(body) }) });
    return { status: response.status, data: await response.json() };
  } catch { throw Error(`transport_failed_at_${stage}`); }
}
async function api(account, action, data = {}, allowFailure = false) {
  const result = await request(edge, 'POST', { action, ...data }, account.idToken);
  if (!allowFailure) assert.equal(result.status, 200, `${stage}: ${result.status}/${result.data.error ?? 'unknown'}/${result.data.reason ?? ''}`);
  return result;
}
async function command(account, type, payload = {}) {
  const result = await api(account, 'submitMatchCommand', { roomId, commandId: randomUUID(),
    commandType: type, expectedVersion: state.serverVersion, commandPayload: payload });
  state = result.data.state; return result.data;
}
async function firebase(path, method, body) {
  const result = await request(`https://halabessa-card-game1-default-rtdb.firebaseio.com/${path}.json?auth=${encodeURIComponent(accounts[0].idToken)}`, method, body);
  assert.equal(result.status, 200, `fixture Firebase cleanup ${result.status}`);
}
try {
  stage = 'new guest accounts';
  for (let i = 0; i < 4; i++) {
    const signed = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, 'POST', { returnSecureToken: true });
    assert.equal(signed.status, 200); accounts.push({ uid: signed.data.localId, idToken: signed.data.idToken });
  }
  stage = 'private protocol room';
  const created = await api(accounts[0], 'createRoom', { mode: 'classic', maxPoints: 21,
    timerDurationSeconds: 0, isPublic: false, protocolVersion: 1, displayName: 'CodexRewardQA_0' });
  roomId = created.data.roomId; state = created.data.match;
  assert.equal(state.protocolVersion, 1);
  for (let i = 1; i < 4; i++) {
    await api(accounts[i], 'joinRoom', { roomId, displayName: `CodexRewardQA_${i}` });
  }
  console.log(JSON.stringify({ awaitingScopedCleanup: true, roomId, users: accounts.map(a => a.uid) }));
  stage = 'scoped cleanup readiness';
  let ready = false;
  for (let attempt = 0; attempt < 90; attempt++) {
    const checked = await api(accounts[0], 'qaCleanupRewardTest', { roomId, ready: true }, true);
    if (checked.status === 200) { ready = true; break; }
    if (checked.status !== 400) throw Error(`QA cleanup unavailable: ${checked.status}`);
    await wait(2000);
  }
  assert.ok(ready, 'Scoped cleanup must be verified before creating any profiles');
  stage = 'new guest profiles';
  for (let i = 0; i < 4; i++) {
    const result = await request(`${documents}/users?documentId=${accounts[i].uid}`, 'POST', { fields: {
      displayName: { stringValue: `CodexRewardQA_${i}` }, points: { integerValue: '20' },
      coins: { integerValue: '200' }, diamonds: { integerValue: '77' }, wins: { integerValue: '3' },
      losses: { integerValue: '0' }, gamesPlayed: { integerValue: '3' }, bestScore: { integerValue: '99' },
      owned_skins: { arrayValue: { values: [{ stringValue: 'qa_preserve_skin' }] } },
    } }, accounts[i].idToken);
    assert.equal(result.status, 200, `profile creation ${result.status}`); profilesCreated = true;
  }
  state = (await api(accounts[0], 'getMatchSnapshot', { roomId })).data.state;
  const seats = state.playerIds.map(uid => accounts.find(a => a.uid === uid));
  let hands = {}; let plays = 0, lastRound = 0;
  stage = 'full authoritative match';
  for (let step = 0; step < 1800 && state.phase !== 'rematchVoting'; step++) {
    if (state.roundCount !== lastRound) {
      lastRound = state.roundCount;
      console.log(JSON.stringify({ round: lastRound, scoreA: state.teamAScore ?? 0, scoreB: state.teamBScore ?? 0, plays }));
    }
    if (state.phase === 'preRoundCut') {
      await command(seats[(state.dealerIndex + 3) % 4], 'cut', { position: 20 });
    } else if (state.phase === 'playing') {
      if (state.playerIds.every(uid => !(state.handCounts?.[uid] ?? 0))) { await command(accounts[0], 'advance'); continue; }
      if (state.playerIds.some(uid => (state.handCounts?.[uid] ?? 0) > (hands[uid]?.length ?? 0))) {
        for (const account of seats) {
          const snapshot = (await api(account, 'getMatchSnapshot', { roomId })).data;
          hands[account.uid] = snapshot.hand; assert.equal('handCards' in snapshot.state, false);
        }
      }
      const seat = state.currentTurnIndex, actor = seats[seat], hand = hands[actor.uid];
      assert.ok(hand?.length, 'current human has a card');
      const top = state.board?.at(-1)?.rank;
      const card = (seat % 2 === 0 ? hand.find(c => c.rank === top) : hand.find(c => c.rank !== top)) ?? hand[0];
      const result = await command(actor, 'playCard', { card }); hands[actor.uid] = result.hand; plays++;
    } else if (state.phase === 'shuffleVoting') {
      for (const account of seats) await command(account, 'voteShuffle', { vote: true });
      await command(accounts[0], 'advance');
    } else {
      const delay = state.phase === 'capturing' ? 1300 : ['dealingCards', 'roundScoring'].includes(state.phase) ? 5100 : 0;
      if (delay) await wait(delay - (Date.now() - Date.parse(state.phaseStartedAt)));
      await command(accounts[0], 'advance');
    }
  }
  assert.equal(state.phase, 'rematchVoting'); assert.equal(state.settlementPending, true);
  console.log(JSON.stringify({ matchFinished: true, rounds: state.roundCount, plays }));
  stage = 'concurrent reward settlement';
  const settled = await Promise.all(seats.slice(0, 2).map(a => api(a, 'settleMatchRewards', { roomId })));
  assert.equal(settled.filter(r => r.data.duplicate === false).length, 1);
  state = settled[1].data.state; assert.equal(state.settlementPending, false);
  const receipt = state.rewardReceiptId; assert.match(receipt, /^[a-f0-9]{64}$/);
  const duplicate = (await api(seats[2], 'settleMatchRewards', { roomId })).data;
  assert.equal(duplicate.duplicate, true); assert.equal(duplicate.version, state.serverVersion);
  for (let seat = 0; seat < 4; seat++) {
    const account = seats[seat], winner = state.rewardScores.teamA >= state.maxPoints ? 0 : 1;
    const won = seat % 2 === winner;
    const read = await request(`${documents}/users/${account.uid}`, 'GET', null, account.idToken);
    assert.equal(read.status, 200); const fields = read.data.fields;
    assert.equal(Number(fields.coins.integerValue), won ? 300 : 220);
    assert.equal(Number(fields.points.integerValue), won ? 70 : 0);
    assert.equal(Number(fields.gamesPlayed.integerValue), 4);
    assert.equal(Number(fields.wins.integerValue), won ? 4 : 3);
    assert.equal(Number(fields.losses.integerValue), won ? 0 : 1);
    assert.equal(Number(fields.diamonds.integerValue), 77); assert.equal(Number(fields.bestScore.integerValue), 99);
    assert.equal(fields.owned_skins.arrayValue.values[0].stringValue, 'qa_preserve_skin');
  }
  console.log(JSON.stringify({ passed: true, rewardsCreditedOnce: true, existingProfileFieldsPreserved: true, receiptId: receipt }));
} catch (error) {
  console.error(JSON.stringify({ passed: false, stage, message: error.message })); process.exitCode = 1;
} finally {
  stage = 'fixture cleanup'; let firestoreCleaned = !profilesCreated, firebaseCleaned = !roomId;
  if (roomId && accounts[0]) {
    try { firestoreCleaned = (await api(accounts[0], 'qaCleanupRewardTest', { roomId }, true)).status === 200; } catch {}
    try {
      await firebase(`matches/${roomId}/expireAt`, 'PUT', new Date(Date.now() - 1000).toISOString());
      await api(accounts[0], 'refreshRoomIndex', { roomId });
      await firebase('', 'PATCH', { [`matches/${roomId}`]: null, [`matchHands/${roomId}`]: null }); firebaseCleaned = true;
    } catch {}
  }
  let accountsDeleted = 0;
  for (const account of accounts) {
    try { if ((await request(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${apiKey}`, 'POST', { idToken: account.idToken })).status === 200) accountsDeleted++; } catch {}
  }
  console.log(JSON.stringify({ fixture: { roomId, users: accounts.map(a => a.uid), firestoreCleaned, firebaseCleaned, accountsDeleted, sqlCleanupRequired: true } }));
}
