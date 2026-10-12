-- Keep recovery beside the verified transaction pooler, like client commands.
-- Preserve the current activation flag; routing never authorizes more rooms.
select cron.alter_job((select jobid from cron.job where jobname='halabessa-match-progress'),
  command := $cron$
  select net.http_post(
    url:='https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api',
    headers:=jsonb_build_object('Content-Type','application/json','x-region','eu-west-2',
      'x-publication-worker',(select decrypted_secret from vault.decrypted_secrets
        where name='halabessa_publication_worker' limit 1)),
    body:='{"action":"advanceScheduledMatches"}'::jsonb,timeout_milliseconds:=55000
  ) where exists(select 1 from halabessa.room_progress_jobs p
    join halabessa.publication_worker_config c on c.singleton=true
    where p.next_attempt_at<=now() and p.due_at<=now()
      and (c.progress_enabled or c.progress_canary_room_id=p.room_id));
  $cron$);
