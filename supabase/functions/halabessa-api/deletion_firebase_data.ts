// Idempotent server adapters, not an independently callable deletion endpoint.
// Authorization and a durable deletion job must precede these operations.
type Document = {name: string; updateTime: string; fields?: Record<string, any>};
const socialFields = ['friends', 'pendingFriendRequests', 'sentFriendRequests'];
const limit = 40;
function validUid(uid: string) {
  if (!/^[A-Za-z0-9:_-]{1,128}$/.test(uid)) throw new Error('invalid_deletion_uid');
}
export function createFirebaseDeletionDataStore(project: string,
  token: () => Promise<string>, fetcher: typeof fetch = fetch) {
  if (!/^[a-z][a-z0-9-]{4,62}$/.test(project)) throw new Error('invalid_identity_project');
  const base = `projects/${project}/databases/(default)/documents`;
  async function request(path: string, body?: unknown) {
    let response: Response;
    try {
      response = await fetcher(`https://firestore.googleapis.com/v1/${base}${path}`, {
        method: body === undefined ? 'GET' : 'POST', signal: AbortSignal.timeout(8000),
        headers: {Authorization: `Bearer ${await token()}`, 'Content-Type': 'application/json'},
        ...(body === undefined ? {} : {body: JSON.stringify(body)}),
      });
    } catch { throw new Error('deletion_data_unavailable'); }
    if (body === undefined && response.status === 404) return null;
    // Only GET absence is success. Permission failures/outages remain pending.
    if (!response.ok) throw new Error('deletion_data_unavailable');
    try { return await response.json(); } catch { throw new Error('deletion_data_unavailable'); }
  }
  function document(value: any, collection: 'users' | 'usernames'): Document {
    const prefix = `${base}/${collection}/`;
    if (!value || typeof value.name !== 'string' || !value.name.startsWith(prefix) ||
        !value.name.slice(prefix.length) || value.name.slice(prefix.length).includes('/') ||
        typeof value.updateTime !== 'string' || !value.updateTime) {
      throw new Error('invalid_deletion_document');
    }
    return value;
  }
  async function query(collection: 'users' | 'usernames', field: string, uid: string, op: string) {
    const rows = await request(':runQuery', {structuredQuery: {
      from: [{collectionId: collection}], limit,
      select: {fields: [{fieldPath: field}]},
      where: {fieldFilter: {field: {fieldPath: field}, op, value: {stringValue: uid}}},
    }});
    if (!Array.isArray(rows)) throw new Error('invalid_deletion_document');
    const found = rows.filter(row => row?.document).map(row => document(row.document, collection));
    if (found.length > limit) throw new Error('invalid_deletion_document');
    return found;
  }
  async function commit(writes: Record<string, unknown>[]) {
    if (writes.length) await request(':commit', {writes});
  }
  return {
    async block(uid: string) {
      validUid(uid);
      await commit([{update: {name: `${base}/accountDeletionBlocked/${uid}`,
        fields: {blocked: {booleanValue: true}}}}]);
    },
    async removeSocialEdges(uid: string) {
      validUid(uid);
      for (const field of socialFields) {
        const rows = await query('users', field, uid, 'ARRAY_CONTAINS');
        for (const row of rows) {
          // Validate the actual returned association before touching a peer.
          if (!row.fields?.[field]?.arrayValue?.values?.some((v: any) => v?.stringValue === uid)) {
            throw new Error('invalid_deletion_document');
          }
        }
        await commit(rows.map(row => ({
          // Field transforms preserve peers' wallets, statistics and concurrent
          // additions. The read-version precondition never resurrects a peer.
          transform: {document: row.name, fieldTransforms: [{fieldPath: field,
            removeAllFromArray: {values: [{stringValue: uid}]}}]},
          currentDocument: {updateTime: row.updateTime},
        })));
        // Bounded work: do not mark this stage complete until a subsequent pass
        // observes fewer than the query limit. External writes are idempotent.
        if (rows.length === limit) throw new Error('deletion_more_data');
      }
    },
    async removeProfileAndReservations(uid: string) {
      validUid(uid);
      const rows = await query('usernames', 'uid', uid, 'EQUAL');
      for (const row of rows) {
        if (row.fields?.uid?.stringValue !== uid) throw new Error('invalid_deletion_document');
      }
      await commit(rows.map(row => ({delete: row.name, currentDocument: {updateTime: row.updateTime}})));
      if (rows.length === limit) throw new Error('deletion_more_data');
      const raw = await request(`/users/${encodeURIComponent(uid)}`);
      if (raw !== null) {
        const own = document(raw, 'users');
        if (own.name !== `${base}/users/${uid}`) throw new Error('invalid_deletion_document');
        await commit([{delete: own.name, currentDocument: {updateTime: own.updateTime}}]);
      }
    },
  };
}
