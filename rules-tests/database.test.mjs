import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { ref, get, set, update, remove, serverTimestamp, query, orderByChild, equalTo, limitToFirst } from 'firebase/database';

// Rules tests must never reach production or a remote emulator host.
assert.match(process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
const rules = await readFile(new URL('../database.rules.json', import.meta.url), 'utf8');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-halabessa-ui', database: { rules } });
});
beforeEach(async () => {
  await env.clearDatabase();
  await env.withSecurityRulesDisabled(async context => {
    const server = { protocolVersion: 1, serverVersion: 8,
      players: { alice: true, bob: true }, playerIds: ['alice', 'bob', 'bot_1', 'bot_2'],
      phase: 'playing', teamAScore: 0, playerNames: { alice: 'Alice', bob: 'Bob' } };
    await set(ref(context.database()), {
      matches: { SERVER: server, LEGACY: { ...server, protocolVersion: 0 },
        OLD: { players: { alice: true }, phase: 'playing' },
        FUTURE: { ...server, protocolVersion: 2 } },
      matchHands: { SERVER: { alice: ['ace'], bob: ['king'] }, LEGACY: { alice: ['ace'], bob: ['king'] } },
      matchSecrets: { SERVER: { deck: ['queen'] } }, rooms: { SERVER: { phase: 'playing' } },
    });
  });
});
after(async () => { await env?.cleanup(); });
const db = uid => env.authenticatedContext(uid).database();
test('deletion block denies retained-token access without affecting unrelated players', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await set(ref(context.database(),'accountDeletionBlocked/alice'),true);
  });
  await assertFails(get(ref(db('alice'),'matches/SERVER')));
  await assertFails(get(ref(db('alice'),'matchHands/SERVER/alice')));
  await assertFails(set(ref(db('alice'),'users/alice'),{displayName:'Recreated'}));
  await assertFails(set(ref(db('alice'),'userPresence/alice/connection'),{lastSeen:serverTimestamp()}));
  await assertFails(remove(ref(db('alice'),'accountDeletionBlocked/alice')));
  await assertFails(get(ref(db('alice'),'accountDeletionBlocked/alice')));
  await assertSucceeds(get(ref(db('bob'),'matches/SERVER')));
});
test('legacy profile mirror is private and its root cannot be enumerated', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await set(ref(context.database(), 'users/alice'), {email: 'private@example.test'});
  });
  await assertSucceeds(get(ref(db('alice'), 'users/alice')));
  await assertFails(get(ref(db('bob'), 'users/alice')));
  await assertFails(get(ref(db('alice'), 'users')));
});
const message = (senderId = 'alice') => ({ id: 'client-id', senderId, senderName: 'Alice',
  text: 'Hello', timestamp: Date.now(), isQuickChat: false });
test('sender-indexed chat queries remain bounded and cannot bypass team privacy', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await set(ref(context.database(),'matchChat/SERVER/public'),{
      mine:{...message('alice'),id:'mine'}, other:{...message('bob'),id:'other'},
    });
    await set(ref(context.database(),'matchChat/SERVER/teamA/mine'),{...message(),id:'mine'});
  });
  const authored = (database,path) => query(ref(database,path),orderByChild('senderId'),equalTo('alice'),limitToFirst(40));
  const found = await assertSucceeds(get(authored(db('alice'),'matchChat/SERVER/public')));
  assert.deepEqual(Object.keys(found.val()),['mine']);
  await assertFails(get(authored(db('bob'),'matchChat/SERVER/teamA')));
  await assertFails(get(authored(db('stranger'),'matchChat/SERVER/public')));
});
test('new team chat excludes opponents, outsiders and released seats', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await set(ref(context.database(), 'matchChat/SERVER/teamA/one'), {...message(), id: 'one'});
  });
  await assertSucceeds(get(ref(db('alice'), 'matchChat/SERVER/teamA')));
  await assertFails(get(ref(db('bob'), 'matchChat/SERVER/teamA')));
  await assertFails(get(ref(db('stranger'), 'matchChat/SERVER/teamA')));
  await assertFails(get(ref(db('alice'), 'matchChat/SERVER')));
  await assertSucceeds(get(ref(db('bob'), 'matchChat/SERVER/public')));
  await assertFails(get(ref(db('stranger'), 'matchChat/SERVER/public')));
  await env.withSecurityRulesDisabled(async context => {
    await update(ref(context.database(), 'matches/SERVER'), {players: {bob: true}, playerIds: ['bot_replacement','bob','bot_1','bot_2']});
  });
  await assertFails(get(ref(db('alice'), 'matchChat/SERVER/teamA')));
});
test('chat sender, server timestamp and rate guard are enforced atomically', async () => {
  const root = ref(db('alice'), 'matchChat/SERVER');
  const send = (id, channel = 'public', sender = 'alice') => update(root, {
    [`${channel}/${id}`]: {...message(sender), id, timestamp: serverTimestamp()},
    'rate/alice': serverTimestamp(),
  });
  await assertFails(send('opponent', 'teamB'));
  await assertFails(send('spoof', 'public', 'bob'));
  await assertSucceeds(send('valid', 'teamA'));
  await assertFails(send('too-fast'));
  await assertFails(set(ref(db('alice'), 'matchChat/SERVER/public/no-rate'), {...message(), id:'no-rate'}));
  await assertFails(set(ref(db('alice'), 'matchChat/SERVER/game/fake'), {...message(), id:'fake'}));
});
test('presence accepts only own server-timestamp connections', async () => {
  await assertSucceeds(set(ref(db('alice'), 'userPresence/alice/browser'), {lastSeen: serverTimestamp()}));
  await assertFails(set(ref(db('bob'), 'userPresence/alice/browser'), {lastSeen: serverTimestamp()}));
  await assertFails(set(ref(db('alice'), 'userPresence/alice/forged'), {lastSeen: 9999999999999}));
  await assertFails(set(ref(db('alice'), 'userPresence/alice/extra'), {lastSeen: serverTimestamp(), name: 'fake'}));
  await assertSucceeds(remove(ref(db('alice'), 'userPresence/alice/browser')));
});

test('seated player reads only their own server hand, not parent or opponents', async () => {
  const alice = db('alice');
  assert.deepEqual((await assertSucceeds(get(ref(alice, 'matchHands/SERVER/alice')))).val(), ['ace']);
  await assertFails(get(ref(alice, 'matchHands/SERVER')));
  await assertFails(get(ref(alice, 'matchHands/SERVER/bob')));
  await assertFails(get(ref(alice, 'matchHands')));
  await assertFails(get(ref(alice, 'matchSecrets/SERVER')));
});
test('outsider cannot read hands but can browse public match/index', async () => {
  const stranger = db('stranger');
  await assertFails(get(ref(stranger, 'matchHands/SERVER/alice')));
  await assertSucceeds(get(ref(stranger, 'matches/SERVER')));
  await assertSucceeds(get(ref(stranger, 'rooms')));
  await assertFails(get(ref(env.unauthenticatedContext().database(), 'matches/SERVER')));
});
test('server state, own hands and lifecycle fields cannot be client written', async () => {
  const alice = db('alice');
  for (const [path, value] of [
    ['matches/SERVER/teamAScore', 999], ['matches/SERVER/serverVersion', 99],
    ['matches/SERVER/phase', 'matchOver'], ['matches/SERVER/players/alice', null],
    ['matches/SERVER/protocolVersion', 0], ['matchHands/SERVER/alice', ['queen']],
    ['matchHands/SERVER/bob', []], ['matches/SERVER/playerEmojis/alice', '🙂'],
    ['matches/SERVER', { protocolVersion: 0, players: { alice: true } }],
  ]) await assertFails(set(ref(alice, path), value));
  await assertFails(remove(ref(alice, 'matches/SERVER')));
});
test('multi-path writes cannot hide state forgery behind permitted presence', async () => {
  await assertSucceeds(update(ref(db('alice')), {
    'matches/SERVER/presence/alice': true,
    'matches/SERVER/playerLastActive/alice': new Date().toISOString(),
  }));
  await assertFails(update(ref(db('alice')), {
    'matches/SERVER/presence/alice': true, 'matches/SERVER/teamAScore': 999,
  }));
  await assertFails(update(ref(db('alice')), {
    'matches/SERVER/protocolVersion': 0, 'matchHands/SERVER/bob': ['queen'],
  }));
});
test('own presence and heartbeat support connect/disconnect only while seated', async () => {
  const alice = db('alice');
  await assertSucceeds(set(ref(alice, 'matches/SERVER/presence/alice'), true));
  await assertSucceeds(remove(ref(alice, 'matches/SERVER/presence/alice')));
  await assertSucceeds(set(ref(alice, 'matches/SERVER/playerLastActive/alice'), new Date().toISOString()));
  await assertSucceeds(remove(ref(alice, 'matches/SERVER/playerLastActive/alice')));
  await assertFails(set(ref(alice, 'matches/SERVER/presence/bob'), true));
  await assertFails(set(ref(alice, 'matches/SERVER/playerLastActive/bob'), 'forged'));
  await assertFails(set(ref(alice, 'matches/SERVER/presence/alice'), { injected: true }));
  await assertFails(set(ref(db('stranger'), 'matches/SERVER/presence/stranger'), true));
});
test('released player loses private-hand access and presence write authority', async () => {
  await env.withSecurityRulesDisabled(context => remove(ref(context.database(), 'matches/SERVER/players/alice')));
  await assertFails(get(ref(db('alice'), 'matchHands/SERVER/alice')));
  await assertFails(set(ref(db('alice'), 'matches/SERVER/presence/alice'), true));
});
test('chat is append-only, bounded and tied to actual authenticated sender', async () => {
  const alice = db('alice');
  await assertSucceeds(set(ref(alice, 'matches/SERVER/chat/message1'), message()));
  await assertFails(set(ref(alice, 'matches/SERVER/chat/message1/text'), 'edited'));
  await assertFails(remove(ref(alice, 'matches/SERVER/chat/message1')));
  await assertFails(set(ref(alice, 'matches/SERVER/chat/forged'), message('bob')));
  await assertFails(set(ref(alice, 'matches/SERVER/chat/large'), { ...message(), text: 'x'.repeat(301) }));
  await assertFails(set(ref(alice, 'matches/SERVER/chat/empty'), { ...message(), text: '' }));
  await assertFails(set(ref(alice, 'matches/SERVER/chat/extra'), { ...message(), extra: 'unbounded' }));
  await assertFails(set(ref(db('stranger'), 'matches/SERVER/chat/outsider'), message('stranger')));
});
test('existing legacy and unmarked matches keep their previous client path', async () => {
  const alice = db('alice');
  await assertSucceeds(get(ref(alice, 'matchHands/LEGACY')));
  await assertSucceeds(update(ref(alice, 'matches/LEGACY'), { phase: 'capturing' }));
  await assertSucceeds(set(ref(alice, 'matchHands/LEGACY/bob'), ['queen']));
  await assertSucceeds(update(ref(alice, 'matches/OLD'), { protocolVersion: 0, phase: 'playing' }));
  await assertSucceeds(update(ref(alice), {
    'matches/LEGACY': { protocolVersion: 0, players: { alice: true, bob: true },
      phase: 'playing', handCounts: { alice: 0, bob: 1 } },
    'matchHands/LEGACY/alice': null, 'matchHands/LEGACY/bob': ['queen'],
  }));
  await assertFails(set(ref(alice, 'matches/LEGACY/protocolVersion'), 1));
  await assertFails(set(ref(alice, 'matches/OLD/protocolVersion'), 1));
});
test('clients cannot create authoritative rooms or forge room-index entries', async () => {
  const alice = db('alice');
  await assertFails(set(ref(alice, 'matches/NEW'), { protocolVersion: 1, players: { alice: true } }));
  await assertFails(set(ref(alice, 'rooms/SERVER'), { phase: 'playing', playerIds: ['alice'] }));
  await assertFails(set(ref(alice, 'matchSecrets/SERVER'), { deck: ['ace'] }));
});
test('unknown future protocols fail closed instead of falling back to legacy', async () => {
  const alice = db('alice');
  await assertFails(set(ref(alice, 'matches/FUTURE/teamAScore'), 999));
  await assertFails(set(ref(alice, 'matchHands/FUTURE/alice'), ['queen']));
  await assertFails(set(ref(alice, 'matches/FUTURE/presence/alice'), true));
});
