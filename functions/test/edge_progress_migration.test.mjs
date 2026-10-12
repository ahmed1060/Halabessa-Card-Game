import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const migration = readFileSync(new URL('../../supabase/migrations/20261012072009_durable_room_progress.sql', import.meta.url), 'utf8');
const regional = readFileSync(new URL('../../supabase/migrations/20261012082710_regional_progress_recovery.sql', import.meta.url), 'utf8');

test('progress rollout is disabled and its repair schedule starts inactive', () => {
  assert.match(migration, /progress_enabled boolean not null default false/);
  assert.match(migration, /active:=false/);
  assert.match(migration, /progress_canary_room_id ~ '\^\[A-Z\]\{3\}\[0-9\]\{5\}\$'/);
  assert.match(migration, /where exists\(select 1 from halabessa.room_progress_jobs/);
});

test('regional recovery changes routing only and preserves room and activation gates', () => {
  assert.match(regional, /'x-region','eu-west-2'/);
  assert.match(regional, /c.progress_enabled or c.progress_canary_room_id=p.room_id/);
  assert.match(regional, /where exists\(select 1 from halabessa.room_progress_jobs/);
  assert.doesNotMatch(regional, /active\s*:=|update halabessa.rooms|delete from|security definer/i);
});
test('durable progress jobs stay private and follow room deletion without deleting accounts', () => {
  assert.match(migration, /references halabessa.rooms\(room_id\) on delete cascade/);
  assert.match(migration, /room_progress_jobs enable row level security/);
  assert.match(migration, /revoke all on halabessa.room_progress_jobs from public,anon,authenticated/);
  assert.match(migration, /security invoker set search_path=''/);
  assert.doesNotMatch(migration, /security definer|delete from halabessa.user_profiles|truncate|drop table/i);
  assert.match(migration, /after insert or update of version/);
});
