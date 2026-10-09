-- Server-only cleanup inventory and a narrowly scoped scheduled-worker key.
create table halabessa.account_deletion_inventory (
  job_id uuid not null references halabessa.account_deletion_jobs(id) on delete cascade,
  kind text not null check (kind in ('peer','room','invite','scan')),
  item text not null check (length(item) between 1 and 260),
  processed boolean not null default false,
  primary key(job_id,kind,item)
);
alter table halabessa.account_deletion_inventory enable row level security;
create policy deny_deletion_inventory on halabessa.account_deletion_inventory
  for all to anon,authenticated using(false) with check(false);
revoke all on halabessa.account_deletion_inventory from public,anon,authenticated;
create unique index account_deletion_receipt_unique on halabessa.account_deletion_jobs(receipt_hash);
alter table halabessa.account_deletion_jobs
  add column apple_required boolean not null default false,
  add column apple_revoked boolean not null default false;

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;
create table halabessa.deletion_worker_config (
  singleton boolean primary key default true check(singleton),
  key_hash text not null check(key_hash ~ '^[a-f0-9]{64}$')
);
alter table halabessa.deletion_worker_config enable row level security;
create policy deny_deletion_worker_config on halabessa.deletion_worker_config
  for all to anon,authenticated using(false) with check(false);
revoke all on halabessa.deletion_worker_config from public,anon,authenticated;
do $$
declare worker_key text;
begin
  worker_key := encode(extensions.gen_random_bytes(32),'hex');
  perform vault.create_secret(worker_key,'halabessa_deletion_worker','Deletion worker only; never a user credential');
  insert into halabessa.deletion_worker_config(key_hash)
    values(encode(extensions.digest(worker_key,'sha256'),'hex'));
end $$;
-- Idle projects make no Edge/network calls. The secret stays in Vault and is
-- neither embedded in a public function nor returned by the deployment.
select cron.schedule('halabessa-account-deletion','* * * * *', $cron$
  select net.http_post(
    url := 'https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api',
    headers := jsonb_build_object('Content-Type','application/json','x-deletion-worker',
      (select decrypted_secret from vault.decrypted_secrets where name='halabessa_deletion_worker' limit 1)),
    body := '{"action":"continueAccountDeletion"}'::jsonb,
    timeout_milliseconds := 55000
  ) where exists(select 1 from halabessa.account_deletion_jobs where status='pending');
$cron$);
