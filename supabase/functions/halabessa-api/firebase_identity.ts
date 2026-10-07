// Server-only Identity Toolkit adapter. Callers must authorize self-deletion
// and persist a cleanup job before calling disableAndRevoke/deleteIdentity.
// This module is deliberately not an HTTP action until the durable adapters,
// Firebase access guards and receipt/recovery flow are ready.
export type FirebaseIdentity = {
  uid: string;
  email: string | null;
  disabled: boolean;
  validSince: number;
  verifiedGuest: boolean;
  admin: boolean;
  providers: string[];
};

function uidValue(uid: string) {
  if (typeof uid !== 'string' || !uid || uid.length > 128 || /[\x00-\x20/#?]/.test(uid)) {
    throw new Error('invalid_identity_uid');
  }
  return uid;
}

function identity(value: unknown, uid: string): FirebaseIdentity {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('invalid_identity_response');
  const row = value as Record<string, unknown>;
  if (row.localId !== uid || (row.disabled !== undefined && typeof row.disabled !== 'boolean')) {
    throw new Error('invalid_identity_response');
  }
  const validSince = row.validSince === undefined ? 0 :
    typeof row.validSince === 'string' && /^\d+$/.test(row.validSince) ? Number(row.validSince) : NaN;
  if (!Number.isSafeInteger(validSince) || validSince < 0) throw new Error('invalid_identity_response');
  const providerInfo = row.providerUserInfo === undefined ? [] : row.providerUserInfo;
  if (!Array.isArray(providerInfo)) throw new Error('invalid_identity_response');
  const providers = providerInfo.map(provider => {
    if (!provider || typeof provider !== 'object' || typeof provider.providerId !== 'string' || !provider.providerId) {
      throw new Error('invalid_identity_response');
    }
    return provider.providerId as string;
  });
  let claims: Record<string, unknown> = {};
  if (row.customAttributes !== undefined) {
    if (typeof row.customAttributes !== 'string') throw new Error('invalid_identity_response');
    try {
      const parsed = JSON.parse(row.customAttributes);
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error();
      claims = parsed;
    } catch { throw new Error('invalid_identity_response'); }
  }
  // Live account data, never the token's potentially stale anonymous-provider
  // claim, determines whether the credentialless guest exception is allowed.
  const credentialFields = ['email', 'phoneNumber', 'passwordHash', 'passwordSalt'];
  for (const field of credentialFields) {
    if (row[field] !== undefined && typeof row[field] !== 'string') throw new Error('invalid_identity_response');
  }
  return {
    uid, email: typeof row.email === 'string' && row.email ? row.email : null,
    disabled: row.disabled === true, validSince, providers,
    verifiedGuest: providers.length === 0 && credentialFields.every(field => !row[field]),
    admin: claims.admin === true,
  };
}

export function assertActiveIdentity(account: FirebaseIdentity | null, authTime: unknown) {
  if (!account || account.disabled || typeof authTime !== 'number' ||
      !Number.isSafeInteger(authTime) || authTime < 0 || authTime < account.validSince) {
    throw new Error('unauthenticated');
  }
}

export function createFirebaseIdentityStore(project: string, accessToken: () => Promise<string>,
  request: typeof fetch = fetch) {
  if (!/^[a-z][a-z0-9-]{4,62}$/.test(project)) throw new Error('invalid_identity_project');
  async function send(action: string, body: Record<string, unknown>, allowMissing = false) {
    let response: Response;
    try {
      response = await request(`https://identitytoolkit.googleapis.com/v1/accounts:${action}`, {
        method: 'POST', signal: AbortSignal.timeout(12_000),
        headers: {Authorization: `Bearer ${await accessToken()}`, 'Content-Type': 'application/json'},
        body: JSON.stringify({...body, targetProjectId: project}),
      });
    } catch { throw new Error('identity_service_unavailable'); }
    let data: any;
    try { data = await response.json(); } catch { throw new Error('invalid_identity_response'); }
    if (!response.ok) {
      // Only explicit absence is idempotent success. Permission errors,
      // throttling and outages must keep the deletion job pending.
      if (allowMissing && response.status === 400 && data?.error?.message === 'USER_NOT_FOUND') return null;
      throw new Error('identity_request_failed');
    }
    if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error('invalid_identity_response');
    return data;
  }
  return {
    async lookup(uid: string): Promise<FirebaseIdentity | null> {
      uidValue(uid);
      const data = await send('lookup', {localId: [uid]});
      // A successful lookup without users means no matching account.
      const users = data.users === undefined ? [] : data.users;
      if (!Array.isArray(users) || users.length > 1) throw new Error('invalid_identity_response');
      return users.length === 0 ? null : identity(users[0], uid);
    },
    async disableAndRevoke(uid: string, nowSeconds: number) {
      uidValue(uid);
      if (!Number.isSafeInteger(nowSeconds) || nowSeconds < 0) throw new Error('invalid_revocation_time');
      await send('update', {localId: uid, disableUser: true, validSince: String(nowSeconds)}, true);
    },
    async deleteIdentity(uid: string) {
      uidValue(uid);
      await send('delete', {localId: uid}, true);
    },
  };
}
