-- Apply the deletion tombstone to ALL shadow-profile writers, including a
-- friend's request/invite. Checking only the current API caller is insufficient.
-- Private invoker trigger: no elevated/public RPC or client grants.
create function halabessa.reject_deleting_profile_write()
returns trigger language plpgsql security invoker
set search_path = pg_catalog, halabessa
as $$
begin
  if exists (select 1 from halabessa.account_deletion_jobs
             where firebase_uid = new.firebase_uid) then
    raise exception 'account_unavailable' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
revoke all on function halabessa.reject_deleting_profile_write()
  from public, anon, authenticated;
create trigger reject_deleting_profile_write
before insert or update on halabessa.user_profiles
for each row execute function halabessa.reject_deleting_profile_write();
