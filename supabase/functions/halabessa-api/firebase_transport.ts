import type { MirrorRequest } from './mirror_fencing.ts';

/** Firebase rejects print=silent with conditional requests. Keep CAS/ETags
 * intact; suppress echoed bodies only for supported unconditional writes.
 */
export function createFirebaseDatabaseRequest(databaseUrl: string,
  token: () => Promise<string>, transport: typeof fetch = fetch): MirrorRequest {
  return async (path, method = 'GET', body, etag) => {
    const silent = !etag && ['PUT','POST','PATCH'].includes(method);
    const response = await transport(`${databaseUrl}/${path}.json${silent ? '?print=silent' : ''}`, {
      method, signal: AbortSignal.timeout(12_000),
      headers: {Authorization: `Bearer ${await token()}`, 'Content-Type': 'application/json',
        ...(method === 'GET' ? {'X-Firebase-ETag': 'true'} : {}),
        ...(etag ? {'if-match': etag} : {})},
      ...(body === undefined ? {} : {body: JSON.stringify(body)}),
    });
    const text = await response.text();
    return {status: response.status, data: text ? JSON.parse(text) : null, etag: response.headers.get('etag')};
  };
}
