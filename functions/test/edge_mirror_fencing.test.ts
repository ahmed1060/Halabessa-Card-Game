import test from 'node:test';
import assert from 'node:assert/strict';
import { publishFencedMirror, deleteFencedMirror, type MirrorRequest } from '../../supabase/functions/halabessa-api/mirror_fencing.ts';
import type { CommittedRoom } from '../../supabase/functions/halabessa-api/match_delivery.ts';

const marker = '__halabessaDelivery', id = 'ABC12345';
function room(version: number): CommittedRoom {
  return {version, state: {id, protocolVersion: 1, phase: 'playing', playerIds: ['human', 'peer'],
    players: {human: true, peer: true}}, hands: {human: [{suit: 'hearts', rank: 'ace'}], peer: []}};
}
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>(yes => {resolve = yes;});
  return {promise, resolve};
}
function database() {
  const values = new Map<string, any>(), tags = new Map<string, number>();
  let writes = 0;
  const put = (path: string, value: unknown) => {
    values.set(path, structuredClone(value)); tags.set(path, (tags.get(path) ?? 0) + 1); writes++;
  };
  const request: MirrorRequest = async (path, method = 'GET', body, etag) => {
    const tag = `"${tags.get(path) ?? 0}"`;
    if (method === 'GET') return {status: 200, data: structuredClone(values.get(path) ?? null), etag: tag};
    if (etag && etag !== tag) return {status: 412, data: values.get(path) ?? null, etag: tag};
    if (method === 'PATCH') {
      for (const [key, value] of Object.entries(body as any)) put(key, value);
    } else put(path, body);
    return {status: 200, data: body, etag: null};
  };
  return {values, request, put, writes: () => writes};
}
const summarize = (state: Record<string, unknown>) => ({phase: state.phase});

test('fenced publication preserves live fields and removes private board fields', async () => {
  const db = database();
  db.put(`matches/${id}`, {serverVersion: 2, chat: {m: {text: 'hello'}}, presence: {human: true},
    playerLastActive: {human: 'now'}, actions: {a: true}, handCards: {peer: ['secret']}, deck: ['secret']});
  await publishFencedMirror(db.request, id, room(3), summarize);
  const board = db.values.get(`matches/${id}`);
  assert.equal(board.serverVersion, 3);
  assert.deepEqual(board.chat, {m: {text: 'hello'}});
  assert.deepEqual(board.presence, {human: true});
  assert.equal('handCards' in board, false); assert.equal('deck' in board, false);
  const views = db.values.get(`matchViews/${id}`);
  assert.deepEqual(views.human.hand, room(3).hands.human);
  assert.equal(views.human.state.serverVersion, views.human.version);
  assert.equal('handCards' in views.human.state, false);
  assert.deepEqual(views.peer.hand, []); assert.deepEqual(views[marker], {version: 3});
});

test('a timed-out HTTP PUT arriving after a newer publisher cannot rewind any root', async () => {
  const db = database(), delayed: (() => Promise<unknown>)[] = [];
  const timedOut: MirrorRequest = async (path, method, body, etag) => {
    if (method === 'PUT') {
      delayed.push(() => db.request(path, method, body, etag));
      throw Error('request_timeout');
    }
    return db.request(path, method, body, etag);
  };
  await assert.rejects(publishFencedMirror(timedOut, id, room(4), summarize), /request_timeout/);
  assert.equal(delayed.length, 4);
  await publishFencedMirror(db.request, id, room(5), summarize);
  for (const late of delayed) assert.equal((await late() as any).status, 412);
  for (const root of ['matches', 'matchHands', 'matchViews', 'rooms']) {
    assert.equal(db.values.get(`${root}/${id}`)[marker].version, 5);
  }
  await publishFencedMirror(db.request, id, room(4), summarize);
  assert.equal(db.values.get(`matchViews/${id}`).human.version, 5);
});

test('a conflict refetches live chat and version, with bounded publication-only retries', async () => {
  const db = database(); let conflicts = 0;
  const racing: MirrorRequest = async (path, method, body, etag) => {
    if (path === `matches/${id}` && method === 'PUT' && conflicts++ === 0) {
      db.put(path, {serverVersion: 1, chat: {concurrent: {text: 'keep'}}});
    }
    return db.request(path, method, body, etag);
  };
  await publishFencedMirror(racing, id, room(2), summarize);
  assert.deepEqual(db.values.get(`matches/${id}`).chat, {concurrent: {text: 'keep'}});
  let attempts = 0;
  const alwaysConflicts: MirrorRequest = async (path, method, body, etag) => {
    if (method === 'PUT' && path === `matches/${id}`) {
      attempts++; return {status: 412, data: null, etag: null};
    }
    return db.request(path, method, body, etag);
  };
  await assert.rejects(publishFencedMirror(alwaysConflicts, id, room(3), summarize), /contended/);
  assert.equal(attempts, 3);
  assert.equal(db.values.get(`matchViews/${id}`).human.version, 3); // Partial delivery can be repaired.
  await publishFencedMirror(db.request, id, room(3), summarize);
  assert.equal(db.values.get(`matches/${id}`).serverVersion, 3);
});

test('deletion erases personal data and fences publishers starting before or after deletion', async () => {
  const db = database(); await publishFencedMirror(db.request, id, room(4), summarize);
  const read = await db.request(`matchViews/${id}`);
  await deleteFencedMirror(db.request, id);
  assert.equal((await db.request(`matchViews/${id}`, 'PUT', {human: 'stale'}, read.etag!)).status, 412);
  await assert.rejects(publishFencedMirror(db.request, id, room(5), summarize), /room_deleted/);
  for (const root of ['matches', 'matchHands', 'matchViews', 'rooms']) {
    const data = db.values.get(`${root}/${id}`);
    assert.deepEqual(data, {...(root === 'matches' ? {protocolVersion: 1} : {}), [marker]: {version: 0, deleted: true}});
  }
  await deleteFencedMirror(db.request, id); // Idempotent teardown, not removal of fences.
});

test('publication waits for siblings after a partial failure before releasing its lease', async () => {
  const db = database(), gate = deferred<void>(), entered = deferred<void>();
  let settled = false;
  const failing: MirrorRequest = async (path, method, body, etag) => {
    if (method === 'PUT' && path === `matches/${id}`) throw Error('unavailable');
    if (method === 'PUT' && path === `matchViews/${id}`) {entered.resolve(); await gate.promise;}
    return db.request(path, method, body, etag);
  };
  const work = publishFencedMirror(failing, id, room(1), summarize).catch(error => {settled = true; throw error;});
  const rejection = assert.rejects(work, /unavailable/);
  await entered.promise; await Promise.resolve();
  assert.equal(settled, false); gate.resolve(); await rejection;
});

test('missing ETags, invalid versions and metadata UID collisions fail closed', async () => {
  const db = database();
  const noTag: MirrorRequest = async () => ({status: 200, data: null, etag: null});
  await assert.rejects(publishFencedMirror(noTag, id, room(1), summarize), /read_failed/);
  await assert.rejects(publishFencedMirror(db.request, id, room(-1), summarize), /invalid_mirror_version/);
  const collision = room(1); collision.state.playerIds = [marker];
  await assert.rejects(publishFencedMirror(db.request, id, collision, summarize), /reserved_player_uid/);
  db.put(`matches/${id}`, {[marker]: {version: 'not-a-version'}});
  await assert.rejects(publishFencedMirror(db.request, id, room(1), summarize), /invalid_mirror_version/);
});
