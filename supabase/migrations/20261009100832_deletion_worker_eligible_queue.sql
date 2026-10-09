-- Pending Apple requests wait for verified provider revocation. Do not spend
-- free-tier Edge invocations on jobs the worker is not authorized to process.
select cron.schedule('halabessa-account-deletion','* * * * *', $cron$
  select net.http_post(
    url := 'https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api',
    headers := jsonb_build_object('Content-Type','application/json','x-deletion-worker',
      (select decrypted_secret from vault.decrypted_secrets where name='halabessa_deletion_worker' limit 1)),
    body := '{"action":"continueAccountDeletion"}'::jsonb,
    timeout_milliseconds := 55000
  ) where exists(select 1 from halabessa.account_deletion_jobs
    where status='pending' and (not apple_required or apple_revoked));
$cron$);
