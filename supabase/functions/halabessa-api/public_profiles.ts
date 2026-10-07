// Never return a private users document to a discovery/ranking client.
const fields = ['displayName', 'username', 'avatarUrl', 'searchName', 'points',
  'rank', 'wins', 'losses', 'gamesPlayed', 'bestScore', 'weeklyRanking'];
type Document = { name?: string; fields?: Record<string, any> };
const textFields = new Set(['displayName', 'username', 'avatarUrl', 'searchName', 'week']);
function value(key: string, field: any): unknown {
  if (textFields.has(key)) return typeof field?.stringValue === 'string' ? field.stringValue : null;
  if (field?.integerValue != null) {
    const number = Number(field.integerValue);
    return Number.isSafeInteger(number) ? number : null;
  }
  return null;
}
export function publicProfile(document: Document) {
  const uid = document.name?.split('/').pop();
  if (!uid) throw new Error('invalid_public_profile');
  const profile: Record<string, unknown> = { uid };
  for (const key of fields) {
    if (key === 'weeklyRanking') continue;
    if (document.fields?.[key] != null) profile[key] = value(key, document.fields[key]);
  }
  const weekly: Record<string, unknown> = {};
  const raw = document.fields?.weeklyRanking?.mapValue?.fields ?? {};
  for (const key of ['week', 'points', 'wins', 'losses', 'gamesPlayed', 'bestScore']) {
    if (raw[key] != null) weekly[key] = value(key, raw[key]);
  }
  if (Object.keys(weekly).length) profile.weeklyRanking = weekly;
  return profile;
}
export function createPublicProfileStore(project: string, token: () => Promise<string>, fetcher = fetch) {
  const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
  async function request(path: string, body?: unknown) {
    const response = await fetcher(`${base}${path}`, {
      method: body == null ? 'GET' : 'POST', signal: AbortSignal.timeout(5000),
      headers: { Authorization: `Bearer ${await token()}`, 'Content-Type': 'application/json' },
      ...(body == null ? {} : { body: JSON.stringify(body) }),
    });
    if (response.status === 404) return null;
    if (!response.ok) throw new Error('public_profiles_unavailable');
    return response.json();
  }
  return {
    async get(uid: unknown) {
      if (typeof uid !== 'string' || !/^[A-Za-z0-9:_-]{1,128}$/.test(uid)) throw new Error('invalid_profile_query');
      const data = await request(`/users/${encodeURIComponent(uid)}`);
      return data ? publicProfile(data) : null;
    },
    async query(options: { search?: unknown; category?: unknown; week?: unknown }) {
      const query: Record<string, any> = { from: [{ collectionId: 'users' }],
        select: { fields: fields.map(fieldPath => ({ fieldPath })) }, limit: 50 };
      if (options.search != null) {
        if (typeof options.search !== 'string') throw new Error('invalid_profile_query');
        const search = options.search.toLowerCase().replaceAll('@', '').trim();
        if (search.length < 2 || search.length > 64) return [];
        query.limit = 20;
        query.where = { compositeFilter: { op: 'AND', filters: [
          { fieldFilter: { field: { fieldPath: 'searchName' }, op: 'GREATER_THAN_OR_EQUAL', value: { stringValue: search } } },
          { fieldFilter: { field: { fieldPath: 'searchName' }, op: 'LESS_THAN_OR_EQUAL', value: { stringValue: search + '\uf8ff' } } },
        ] } };
        query.orderBy = [{ field: { fieldPath: 'searchName' }, direction: 'ASCENDING' }];
      } else {
        if (!['points', 'wins', 'bestScore'].includes(String(options.category))) throw new Error('invalid_profile_query');
        if (options.week != null && (typeof options.week !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(options.week))) throw new Error('invalid_profile_query');
        const fieldPath = options.week == null ? String(options.category) : `weeklyRanking.${options.category}`;
        query.orderBy = [{ field: { fieldPath }, direction: 'DESCENDING' }];
        if (options.week != null) query.where = { fieldFilter: { field: { fieldPath: 'weeklyRanking.week' },
          op: 'EQUAL', value: { stringValue: options.week } } };
      }
      const data = await request(':runQuery', { structuredQuery: query });
      if (!Array.isArray(data)) throw new Error('public_profiles_unavailable');
      return data.filter(row => row.document).map(row => publicProfile(row.document));
    },
  };
}
