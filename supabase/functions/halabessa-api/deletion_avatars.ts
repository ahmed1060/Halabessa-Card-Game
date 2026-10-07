// Use Storage's API, never delete storage.objects rows directly: SQL metadata
// removal does not delete the actual uploaded object. No bucket-wide operation.
export function createDeletionAvatarStore(url: string, serviceKey: string, fetcher: typeof fetch = fetch) {
  const parsed = new URL(url);
  if (parsed.protocol !== 'https:' || !serviceKey) throw new Error('storage_not_configured');
  return {
    async remove(uid: string) {
      // The historical uploader sanitizes/truncates UIDs. Such paths could
      // collide with another account. Refuse ambiguous legacy paths rather than
      // deleting somebody else's files, and never use a client-provided URL.
      if (!/^[A-Za-z0-9_-]{1,80}$/.test(uid)) throw new Error('ambiguous_avatar_owner');
      // The historical endpoint accepted audio MIME types even for avatar
      // uploads. Remove all six previously possible variants, not just images.
      const prefixes = ['jpg','png','webp','mp3','wav','m4a'].map(extension => `avatars/${uid}/profile.${extension}`);
      let response: Response;
      try {
        response = await fetcher(`${parsed.origin}/storage/v1/object/game-assets`, {
          method: 'DELETE', signal: AbortSignal.timeout(8000),
          headers: {Authorization: `Bearer ${serviceKey}`, apikey: serviceKey, 'Content-Type': 'application/json'},
          body: JSON.stringify({prefixes}),
        });
      } catch { throw new Error('deletion_storage_unavailable'); }
      // Missing individual objects are idempotent API success. A bucket/path
      // 404, denial or upstream failure must NOT count as successful deletion.
      if (!response.ok) throw new Error('deletion_storage_unavailable');
      let data: unknown;
      try { data = await response.json(); } catch { throw new Error('deletion_storage_unavailable'); }
      if (!Array.isArray(data)) throw new Error('deletion_storage_unavailable');
    },
  };
}
