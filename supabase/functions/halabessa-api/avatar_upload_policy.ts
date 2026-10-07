// Only the server-verified account UID chooses an avatar path. Reject legacy
// lossy UID sanitization and MIME types that are not supported avatar images.
export function assertAvatarUpload(kind: unknown, contentType: unknown, uid: string) {
  if (kind !== 'avatar') return; // Other kinds still require caller admin rights.
  if (!['image/jpeg','image/png','image/webp'].includes(String(contentType)) ||
      !/^[A-Za-z0-9_-]{1,80}$/.test(uid)) throw new Error('invalid_asset');
}
