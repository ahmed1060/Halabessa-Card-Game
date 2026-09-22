-- Edge Functions use the server secret and bypass RLS. Add explicit deny-all
-- policies so no PostgREST client can ever gain access if schema exposure or
-- grants are changed later.
create policy "server_only" on halabessa.user_profiles as restrictive for all using (false) with check (false);
create policy "server_only" on halabessa.friendships as restrictive for all using (false) with check (false);
create policy "server_only" on halabessa.friend_requests as restrictive for all using (false) with check (false);
create policy "server_only" on halabessa.rooms as restrictive for all using (false) with check (false);
create policy "server_only" on halabessa.room_hands as restrictive for all using (false) with check (false);
create policy "server_only" on halabessa.room_secrets as restrictive for all using (false) with check (false);
create policy "server_only" on halabessa.room_invites as restrictive for all using (false) with check (false);

revoke all on function public.rls_auto_enable() from public, anon, authenticated;

create index friendships_friend_uid_idx on halabessa.friendships (friend_uid);
create index friend_requests_recipient_uid_idx on halabessa.friend_requests (recipient_uid);
create index room_hands_firebase_uid_idx on halabessa.room_hands (firebase_uid);
create index room_invites_recipient_uid_idx on halabessa.room_invites (recipient_uid);
create index room_invites_sender_uid_idx on halabessa.room_invites (sender_uid);
create index rooms_owner_uid_idx on halabessa.rooms (owner_uid);
