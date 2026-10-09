-- Public reads are intentional for player avatars, store art, music, and SFX.
-- Uploads remain private because only the Edge Function's service role writes
-- objects; no storage.objects INSERT/UPDATE/DELETE policy is granted to clients.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'game-assets',
  'game-assets',
  true,
  4194304,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'audio/mpeg',
    'audio/wav',
    'audio/mp4'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
