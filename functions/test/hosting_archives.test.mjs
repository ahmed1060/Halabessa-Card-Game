import test from 'node:test';
import assert from 'node:assert/strict';
import { cleanupArchives, planArchivedReleases, versionName, site } from '../../scripts/cleanup-hosting-archives.mjs';

const root = `sites/${site}`;
const version = id => ({ name: `${root}/versions/${id}`, status: 'FINALIZED', versionBytes: '100' });
const release = (id, day) => ({ name: `${root}/channels/live/releases/r-${id}`,
  releaseTime: `2026-10-${String(day).padStart(2, '0')}T12:00:00Z`, version: version(id) });
const live = { name: `${root}/channels/live`, release: release('v5', 5) };
const history = [1, 2, 3, 4, 5].map(day => release(`v${day}`, day));

function fixture({ changeAfterDelete = false, unavailableKept = false, paginated = false } = {}) {
  const calls = [], deleted = [];
  const request = async (path, method = 'GET') => {
    calls.push({ path, method });
    if (method === 'DELETE') { deleted.push(path); return {}; }
    if (path === `${root}/channels/live`) {
      return changeAfterDelete && deleted.length ? { ...live, release: release('v-new', 10) } : live;
    }
    if (path.startsWith(`${root}/channels?`)) return { channels: [live] };
    if (path.startsWith(`${root}/channels/live/releases?`)) {
      if (!paginated) return { releases: history };
      return path.includes('pageToken=second') ? { releases: history.slice(2) } :
        { releases: history.slice(0, 2), nextPageToken: 'second' };
    }
    if (path.startsWith(`${root}/versions/`)) {
      const id = path.split('/').at(-1);
      return { ...version(id), status: unavailableKept && id === 'v4' ? 'DELETED' : 'FINALIZED' };
    }
    throw new Error(`Unexpected fixture call ${method} ${path}`);
  };
  return { calls, deleted, request };
}

test('keep actual live version and two newest distinct rollbacks despite list ordering', () => {
  const plan = planArchivedReleases(history, live, []);
  assert.deepEqual(plan.retained, ['v5', 'v4', 'v3'].map(id => version(id).name));
  assert.deepEqual(plan.candidates, ['v2', 'v1'].map(id => version(id).name));
});

test('rolled-back live version and duplicate release records do not reduce the two rollbacks', () => {
  const rolledBack = { ...live, release: release('v1', 10) };
  const plan = planArchivedReleases([...history, release('v5', 6)], rolledBack, []);
  assert.deepEqual(plan.retained, ['v1', 'v5', 'v4'].map(id => version(id).name));
  assert.equal(new Set(plan.candidates).size, plan.candidates.length);
});

test('a currently serving preview version cannot be deleted even if archived in live history', () => {
  const preview = { name: `${root}/channels/qa`, release: release('v1', 1) };
  const plan = planArchivedReleases(history, live, [preview]);
  assert.deepEqual(plan.candidates, [version('v2').name]);
});

test('deleted versions are not counted as available rollbacks or deletion targets', () => {
  const rows = history.map(row => row.version.name === version('v4').name ?
    { ...row, version: { ...row.version, status: 'DELETED' } } : row);
  const plan = planArchivedReleases(rows, live, []);
  assert.deepEqual(plan.retained, ['v5', 'v3', 'v2'].map(id => version(id).name));
  assert.deepEqual(plan.candidates, [version('v1').name]);
});

test('dry-run is the default and never writes any Hosting data', async () => {
  const fake = fixture();
  const result = await cleanupArchives(fake.request, { log() {} });
  assert.equal(result.plan.candidates.length, 2);
  assert.deepEqual(fake.deleted, []);
  assert.ok(fake.calls.every(call => call.method === 'GET'));
});

test('approved mode deletes only older versions and fences channels before every delete', async () => {
  const fake = fixture({ paginated: true });
  const result = await cleanupArchives(fake.request, { apply: true, log() {} });
  assert.deepEqual(result.deleted, ['v2', 'v1'].map(id => version(id).name));
  assert.ok(fake.calls.every(call => call.path.startsWith(`${root}/`)));
  assert.ok(fake.calls.every(call => call.method === 'GET' ||
    (call.method === 'DELETE' && result.deleted.includes(call.path))));
  assert.equal(fake.calls.filter(call => call.path === `${root}/channels/live`).length, 4);
});

test('change of live release interrupts cleanup before subsequent deletion', async () => {
  const fake = fixture({ changeAfterDelete: true });
  await assert.rejects(cleanupArchives(fake.request, { apply: true, log() {} }), /Channel changed/);
  assert.deepEqual(fake.deleted, [version('v2').name]);
});

test('no deletion starts unless all retained rollback content is verified', async () => {
  const fake = fixture({ unavailableKept: true });
  await assert.rejects(cleanupArchives(fake.request, { apply: true, log() {} }), /Retained version/);
  assert.deepEqual(fake.deleted, []);
});

test('too few available rollbacks and invalid history fail closed', () => {
  assert.throws(() => planArchivedReleases([history[4]], live, []), /two available/);
  assert.throws(() => planArchivedReleases([{ ...history[0], releaseTime: 'invalid' }], live, []), /release time/);
  assert.throws(() => planArchivedReleases([{ ...history[0], name: 'sites/other/releases/r' }], live, []), /outside/);
});

test('resource scope rejects other sites, projects, path traversal, and external URLs', () => {
  for (const name of ['sites/other/versions/id', `${root}/versions/../channels/live`,
    `https://example.com/${root}/versions/id`, `projects/other/${root}/versions/id`,
    `${root}/versions/id?force=true`]) assert.throws(() => versionName(name), /outside/);
  assert.equal(versionName(`projects/${site}/${root}/versions/v1`), version('v1').name);
});
