-- Foundations for server-authoritative, idempotent match commands.
alter table halabessa.rooms
  add column if not exists version bigint not null default 0
  check (version >= 0);

alter table halabessa.room_secrets
  add column if not exists hands jsonb not null default '{}'::jsonb
  check (jsonb_typeof(hands) = 'object');

create table if not exists halabessa.room_commands (
  room_id text not null references halabessa.rooms(room_id) on delete cascade,
  command_id uuid not null,
  actor_uid text not null references halabessa.user_profiles(firebase_uid) on delete cascade,
  action text not null check (action ~ '^[a-z][A-Za-z0-9]{0,63}$'),
  expected_version bigint not null check (expected_version >= 0),
  applied_version bigint not null check (applied_version > expected_version),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  created_at timestamptz not null default now(),
  primary key (room_id, command_id)
);

alter table halabessa.room_commands enable row level security;

drop policy if exists "server_only" on halabessa.room_commands;
create policy "server_only"
  on halabessa.room_commands
  as restrictive
  for all
  using (false)
  with check (false);

revoke all on table halabessa.room_commands from public, anon, authenticated;
