-- Append-only pending revision intents commit with gameplay, without making
-- Filename aligned with the verified production migration history.
-- mutations contend on a publication lease or copy private hands into a queue.
create table halabessa.room_publications (
  room_id text not null references halabessa.rooms(room_id) on delete cascade,
  version bigint not null check(version >= 0),
  created_at timestamptz not null default now(),
  next_attempt_at timestamptz not null default now(),
  attempts integer not null default 0 check(attempts >= 0),
  primary key(room_id,version)
);
create index room_publications_due on halabessa.room_publications(next_attempt_at,created_at);
alter table halabessa.room_publications enable row level security;
revoke all on halabessa.room_publications from public,anon,authenticated;

create function halabessa.enqueue_room_publication() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.state->>'protocolVersion' = '1' then
    insert into halabessa.room_publications(room_id,version)
      values(new.room_id,new.version) on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function halabessa.enqueue_room_publication() from public,anon,authenticated;
create trigger durable_room_publication after insert or update of version
  on halabessa.rooms for each row execute function halabessa.enqueue_room_publication();

-- Only the scheduled repair endpoint uses this key. It is not a Firebase
-- credential or the deletion worker key. Clients cannot enable early ack.
create table halabessa.publication_worker_config (
  singleton boolean primary key default true check(singleton),
  key_hash text not null check(key_hash ~ '^[a-f0-9]{64}$'),
  async_ack_enabled boolean not null default false
);
alter table halabessa.publication_worker_config enable row level security;
revoke all on halabessa.publication_worker_config from public,anon,authenticated;
do $$
declare worker_key text;
begin
  worker_key := encode(extensions.gen_random_bytes(32),'hex');
  perform vault.create_secret(worker_key,'halabessa_publication_worker','Match publication repair only');
  insert into halabessa.publication_worker_config(key_hash)
    values(encode(extensions.digest(worker_key,'sha256'),'hex'));
end $$;

-- No backfill of existing rooms, no idle HTTP invocations, no paid services.
-- The source is deployed before this migration's scheduler is activated.
select cron.alter_job(cron.schedule('halabessa-match-publication','* * * * *', $cron$
  select net.http_post(
    url := 'https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api',
    headers := jsonb_build_object('Content-Type','application/json','x-publication-worker',
      (select decrypted_secret from vault.decrypted_secrets where name='halabessa_publication_worker' limit 1)),
    body := '{"action":"repairMatchDelivery"}'::jsonb,
    timeout_milliseconds := 55000
  ) where exists(select 1 from halabessa.room_publications where next_attempt_at<=now());
-- Activate only after the compatible Edge source is deployed and verified.
$cron$), active := false);
