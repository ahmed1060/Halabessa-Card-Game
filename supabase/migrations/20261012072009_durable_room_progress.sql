-- Compatible rollout: disabled globally and for all rooms until canary QA.
alter table halabessa.publication_worker_config
  add column progress_enabled boolean not null default false,
  add column progress_canary_room_id text
    check(progress_canary_room_id is null or progress_canary_room_id ~ '^[A-Z]{3}[0-9]{5}$');

create table halabessa.room_progress_jobs (
  room_id text primary key references halabessa.rooms(room_id) on delete cascade,
  version bigint not null check(version>=0),
  due_at timestamptz not null,
  next_attempt_at timestamptz not null default now(),
  attempts integer not null default 0 check(attempts>=0)
);
create index room_progress_due on halabessa.room_progress_jobs(next_attempt_at,due_at);
alter table halabessa.room_progress_jobs enable row level security;
revoke all on halabessa.room_progress_jobs from public,anon,authenticated;

create function halabessa.enqueue_room_progress() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if new.state->>'protocolVersion'='1' and new.state->>'progressDueAt' is not null
    and exists(select 1 from halabessa.publication_worker_config c where c.singleton=true
      and (c.progress_enabled or c.progress_canary_room_id=new.room_id)) then
    insert into halabessa.room_progress_jobs(room_id,version,due_at)
      values(new.room_id,new.version,(new.state->>'progressDueAt')::timestamptz)
      on conflict(room_id) do update set version=excluded.version,due_at=excluded.due_at,
        next_attempt_at=now(),attempts=0;
  else
    delete from halabessa.room_progress_jobs where room_id=new.room_id;
  end if;
  return new;
end $$;
revoke all on function halabessa.enqueue_room_progress() from public,anon,authenticated;
create trigger durable_room_progress after insert or update of version
  on halabessa.rooms for each row execute function halabessa.enqueue_room_progress();

-- A repair sweep is recovery only, never the normal bot-play scheduler.
select cron.alter_job(cron.schedule('halabessa-match-progress','* * * * *', $cron$
  select net.http_post(
    url:='https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api',
    headers:=jsonb_build_object('Content-Type','application/json','x-publication-worker',
      (select decrypted_secret from vault.decrypted_secrets where name='halabessa_publication_worker' limit 1)),
    body:='{"action":"advanceScheduledMatches"}'::jsonb,
    timeout_milliseconds:=55000
  ) where exists(select 1 from halabessa.room_progress_jobs p
    join halabessa.publication_worker_config c on c.singleton=true
    where p.next_attempt_at<=now() and p.due_at<=now()
      and (c.progress_enabled or c.progress_canary_room_id=p.room_id));
$cron$),active:=false);
