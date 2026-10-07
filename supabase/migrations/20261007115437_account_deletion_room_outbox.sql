-- Keep delivery intent after SQL anonymization commits. A worker crash or RTDB
-- outage must not make an already-anonymized room disappear from cleanup scans.
create table halabessa.account_deletion_rooms (
  job_id uuid not null references halabessa.account_deletion_jobs(id) on delete cascade,
  room_id text not null check (room_id ~ '^[A-Z]{3}[0-9]{5}$'),
  published boolean not null default false,
  primary key (job_id, room_id)
);
-- Deliberately no room FK: normal room expiration/deletion must not erase the
-- job's delivery/chat-cleanup inventory before its worker observes the removal.
alter table halabessa.account_deletion_rooms enable row level security;
revoke all on table halabessa.account_deletion_rooms from public, anon, authenticated;
create policy deny_client_deletion_room_access on halabessa.account_deletion_rooms
as restrictive for all to anon, authenticated using (false) with check (false);
