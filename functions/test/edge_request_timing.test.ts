import assert from 'node:assert/strict';
import test from 'node:test';
import { createRequestTiming } from '../../supabase/functions/halabessa-api/request_timing.ts';

test('timing labels cannot expose caller payloads or credentials', async () => {
  let now = 0;
  const records: unknown[] = [];
  const timing = createRequestTiming(record => records.push(record), () => now);
  timing.operation('Bearer secret-test');
  timing.observe('user-private-email', 100);
  timing.observe('db_connect', NaN);
  timing.observe('db_connect', -10);
  await timing.measure('jwt', async () => { now = 5; return true; });
  timing.observe('jwt', 2);
  timing.finish();
  assert.deepEqual(records, [{event:'halabessa_timing_v1',operation:'unknown',total_ms:5,stages:{jwt:7}}]);
});

test('failed operations still record bounded stage timing', async () => {
  let now = 0;
  const records: unknown[] = [];
  const timing = createRequestTiming(record => records.push(record), () => now);
  timing.operation('getSocialGraph');
  await assert.rejects(timing.measure('social_query', async () => {
    now = 8; throw new Error('test failure');
  }), /test failure/);
  timing.finish();
  assert.deepEqual(records, [{event:'halabessa_timing_v1',operation:'getSocialGraph',total_ms:8,stages:{social_query:8}}]);
});
