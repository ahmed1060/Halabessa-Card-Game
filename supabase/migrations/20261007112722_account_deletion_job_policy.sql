-- Explicit deny-all policy documents the deliberately private queue.
create policy account_deletion_jobs_client_deny
  on halabessa.account_deletion_jobs as restrictive
  for all to anon, authenticated using (false) with check (false);
