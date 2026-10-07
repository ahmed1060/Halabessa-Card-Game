// Shared guard before any API work, including Firestore-only discovery.
// The deletion worker writes the server-only RTDB block before disabling Auth.
export async function assertNotDeletionBlocked(uid: string,
  read: (path: string) => Promise<{status:number;data:unknown}>) {
  const result = await read(`accountDeletionBlocked/${encodeURIComponent(uid)}`);
  if (result.status < 200 || result.status >= 300) throw new Error('account_guard_unavailable');
  // Presence of ANY value is blocking, matching Firebase exists() rules.
  if (result.data !== null) throw new Error('unauthenticated');
}
