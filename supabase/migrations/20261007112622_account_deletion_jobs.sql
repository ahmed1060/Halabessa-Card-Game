-- Private durable queue only. No endpoint/cron is activated by this migration.
create table halabessa.account_deletion_jobs (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text not null unique check (length(firebase_uid) between 1 and 128),
  receipt_hash text not null check (receipt_hash ~ '^[a-f0-9]{64}$'),
  status text not null default 'pending' check (status in ('pending', 'complete')),
  completed_stages text[] not null default '{}',
  last_failed_stage text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint deletion_stage_prefix check (
    cardinality(completed_stages) between 0 and 6 and completed_stages =
      (array['blockSessions','releaseAndAnonymizeRooms','removeSocialAndMessages',
        'removeProfileAndReservations','removeAvatarObjects','deleteIdentity']::text[])
      [1:cardinality(completed_stages)]
  ),
  constraint deletion_complete_check check (
    (status = 'complete' and cardinality(completed_stages) = 6 and completed_at is not null)
    or (status = 'pending' and completed_at is null)
  ),
  constraint deletion_failed_stage_check check (
    last_failed_stage is null or last_failed_stage = any(array[
      'blockSessions','releaseAndAnonymizeRooms','removeSocialAndMessages',
      'removeProfileAndReservations','removeAvatarObjects','deleteIdentity'])
  )
);
-- No FK: the queue must survive removal of the account it is cleaning up.
alter table halabessa.account_deletion_jobs enable row level security;
revoke all on halabessa.account_deletion_jobs from public, anon, authenticated;
create index account_deletion_pending on halabessa.account_deletion_jobs (updated_at)
  where status = 'pending';
