import test from 'node:test';
import assert from 'node:assert/strict';
import {RevisionTracker} from '../../scripts/performance-feed.mjs';
const view = version => ({version, recipientUid: 'qa', state: {id: 'QA'}});
test('revision waiters register before publication and coalesced newer revisions resolve', async () => {
  const tracker = new RevisionTracker('qa', 'QA');
  const a = tracker.wait(2, 100), b = tracker.wait(3, 100);
  tracker.observe(view(3), 150);
  assert.deepEqual(await a, {version: 3, ms: 50});
  assert.deepEqual(await b, {version: 3, ms: 50});
  assert.equal(tracker.waiters.size, 0);
});
test('private recipient, leaked hands and revision regression are rejected', () => {
  const tracker = new RevisionTracker('qa', 'QA'); tracker.observe(view(3));
  assert.throws(() => tracker.observe(view(2)), /revision_regressed/);
  assert.throws(() => tracker.observe({...view(4), recipientUid: 'other'}), /invalid_private_view/);
  assert.throws(() => tracker.observe({...view(4), state: {id: 'QA', handCards: {}}}), /invalid_private_view/);
});
test('delivery timeout removes its waiter and disconnect rejects pending waits', async () => {
  const tracker = new RevisionTracker('qa', 'QA');
  await assert.rejects(tracker.wait(4, 0, 5), /revision_delivery_timeout/);
  assert.equal(tracker.waiters.size, 0);
  const wait = tracker.wait(5); tracker.fail();
  await assert.rejects(wait, /feed_closed/);
  await assert.rejects(tracker.wait(6), /feed_closed/);
  assert.equal(tracker.waiters.size, 0);
});
