-- Permit isolated live QA without activating early acknowledgments for players.
-- Filename aligned with the verified production migration history.
-- The canary clears automatically when its scoped room is removed.
alter table halabessa.publication_worker_config add column canary_room_id text
  references halabessa.rooms(room_id) on delete set null
  check(canary_room_id is null or canary_room_id ~ '^[A-Z]{3}[0-9]{5}$');
