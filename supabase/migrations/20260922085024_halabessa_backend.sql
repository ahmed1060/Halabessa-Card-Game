-- Server-owned game state. This schema is deliberately absent from the Data
-- API. Edge Functions access it with the server key only after validating the
-- caller's Firebase ID token; browser clients receive no table privileges.
create schema if not exists halabessa;

revoke all on schema halabessa from public, anon, authenticated;

create table halabessa.user_profiles (
  firebase_uid text primary key check (char_length(firebase_uid) between 1 and 128),
  email text,
  display_name text not null default 'Player' check (char_length(display_name) <= 64),
  coins integer not null default 0 check (coins >= 0),
  diamonds integer not null default 0 check (diamonds >= 0),
  daily_reward jsonb not null default '{}'::jsonb,
  profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table halabessa.friendships (
  owner_uid text not null references halabessa.user_profiles(firebase_uid) on delete cascade,
  friend_uid text not null references halabessa.user_profiles(firebase_uid) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_uid, friend_uid),
  check (owner_uid <> friend_uid)
);

create table halabessa.friend_requests (
  sender_uid text not null references halabessa.user_profiles(firebase_uid) on delete cascade,
  recipient_uid text not null references halabessa.user_profiles(firebase_uid) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (sender_uid, recipient_uid),
  check (sender_uid <> recipient_uid)
);

create table halabessa.rooms (
  room_id text primary key check (room_id ~ '^[A-Z]{3}[0-9]{5}$'),
  owner_uid text not null references halabessa.user_profiles(firebase_uid),
  state jsonb not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index rooms_expires_at_idx on halabessa.rooms (expires_at)
  where expires_at is not null;

create table halabessa.room_hands (
  room_id text not null references halabessa.rooms(room_id) on delete cascade,
  firebase_uid text not null references halabessa.user_profiles(firebase_uid) on delete cascade,
  cards jsonb not null default '[]'::jsonb,
  primary key (room_id, firebase_uid)
);

create table halabessa.room_secrets (
  room_id text primary key references halabessa.rooms(room_id) on delete cascade,
  deck jsonb not null default '[]'::jsonb
);

create table halabessa.room_invites (
  room_id text not null references halabessa.rooms(room_id) on delete cascade,
  recipient_uid text not null references halabessa.user_profiles(firebase_uid) on delete cascade,
  sender_uid text not null references halabessa.user_profiles(firebase_uid) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (room_id, recipient_uid)
);

alter table halabessa.user_profiles enable row level security;
alter table halabessa.friendships enable row level security;
alter table halabessa.friend_requests enable row level security;
alter table halabessa.rooms enable row level security;
alter table halabessa.room_hands enable row level security;
alter table halabessa.room_secrets enable row level security;
alter table halabessa.room_invites enable row level security;
