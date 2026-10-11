import { createSign } from 'node:crypto';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const site = 'halabessa-card-game1';
const root = `sites/${site}`;
const api = 'https://firebasehosting.googleapis.com/v1beta1/';
const oauth = 'https://oauth2.googleapis.com/token';

export function versionName(name) {
  const match = /^(?:projects\/(?:halabessa-card-game1|54223815037)\/)?sites\/halabessa-card-game1\/versions\/([A-Za-z0-9_-]+)$/.exec(name ?? '');
  if (!match) throw new Error('Version outside approved Hosting site');
  return `${root}/versions/${match[1]}`;
}

function channelName(name) {
  const match = /^(?:projects\/(?:halabessa-card-game1|54223815037)\/)?sites\/halabessa-card-game1\/channels\/([A-Za-z0-9_-]+)$/.exec(name ?? '');
  if (!match) throw new Error('Channel outside approved Hosting site');
  return `${root}/channels/${match[1]}`;
}

export function planArchivedReleases(releases, live, channels) {
  if (channelName(live.name) !== `${root}/channels/live`) throw new Error('Missing live channel');
  const current = versionName(live.release?.version?.name);
  const active = new Set([current]);
  for (const channel of channels) {
    channelName(channel.name);
    if (channel.release?.version) active.add(versionName(channel.release.version.name));
  }
  const dated = releases.map(release => {
    if (!release.name?.startsWith(`${root}/channels/live/releases/`) &&
        !release.name?.startsWith(`${root}/releases/`) &&
        !release.name?.startsWith(`projects/${site}/${root}/channels/live/releases/`) &&
        !release.name?.startsWith(`projects/54223815037/${root}/channels/live/releases/`)) {
      throw new Error('Release outside approved live history');
    }
    const time = Date.parse(release.releaseTime);
    if (!Number.isFinite(time)) throw new Error('Invalid release time');
    return { version: release.version ? versionName(release.version.name) : null,
      status: release.version?.status, time };
  }).sort((a, b) => b.time - a.time);
  const retained = new Set([current]);
  for (const release of dated) {
    if (release.version && release.status === 'FINALIZED') retained.add(release.version);
    if (retained.size === 3) break;
  }
  if (retained.size !== 3) throw new Error('Cannot verify two available rollback versions');
  const protectedVersions = new Set([...active, ...retained]);
  const candidates = [...new Set(dated.filter(release => release.version &&
    release.status === 'FINALIZED' && !protectedVersions.has(release.version))
    .map(release => release.version))];
  return { current, retained: [...retained], protected: [...protectedVersions], candidates };
}

async function pages(request, path, field) {
  const values = [], seen = new Set();
  let token = '';
  for (let page = 0; page < 100; page++) {
    const data = await request(`${path}?pageSize=100${token ? `&pageToken=${encodeURIComponent(token)}` : ''}`);
    if (data[field] != null && !Array.isArray(data[field])) throw new Error('Invalid Hosting page');
    values.push(...(data[field] ?? []));
    if (!data.nextPageToken) return values;
    token = data.nextPageToken;
    if (seen.has(token)) throw new Error('Repeated Hosting page token');
    seen.add(token);
  }
  throw new Error('Hosting pagination safety limit exceeded');
}

async function readSnapshot(request) {
  const live = await request(`${root}/channels/live`);
  const channels = await pages(request, `${root}/channels`, 'channels');
  const signature = JSON.stringify([live, ...channels].map(channel => [
    channelName(channel.name), channel.release?.name ?? '',
    channel.release?.version ? versionName(channel.release.version.name) : '',
  ]).sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b))));
  return { live, channels, signature };
}

export async function cleanupArchives(request, { apply = false, log = console.log } = {}) {
  const snapshot = await readSnapshot(request);
  const releases = await pages(request, `${root}/channels/live/releases`, 'releases');
  const plan = planArchivedReleases(releases, snapshot.live, snapshot.channels);
  // Verify that all three promised versions still have their content before
  // deleting anything. Unknown/deleted rollback candidates fail closed.
  for (const name of plan.retained) {
    const version = await request(name);
    if (versionName(version.name) !== name || version.status !== 'FINALIZED') {
      throw new Error('Retained version is not available; no cleanup applied');
    }
  }
  log(JSON.stringify({ mode: apply ? 'apply-approved-archives' : 'read-only', ...plan }));
  const deleted = [];
  if (apply) {
    for (const name of plan.candidates) {
      const fresh = await readSnapshot(request);
      if (fresh.signature !== snapshot.signature) throw new Error('Channel changed during cleanup; stopping');
      const version = await request(name);
      if (versionName(version.name) !== name) throw new Error('Unexpected version response');
      if (version.status === 'DELETED' || version.status === 'EXPIRED') continue;
      if (version.status !== 'FINALIZED' || plan.protected.includes(name)) {
        throw new Error('Candidate is no longer an approved archived version');
      }
      await request(name, 'DELETE');
      deleted.push(name);
      log(JSON.stringify({ deleted: name, archivedBytes: version.versionBytes ?? null }));
    }
    if ((await readSnapshot(request)).signature !== snapshot.signature) {
      throw new Error('Channel changed after cleanup; verify deployment before continuing');
    }
  }
  log(JSON.stringify({ deletedCount: deleted.length, retained: plan.retained,
    liveVersionUnchanged: true, quotaReclamationMayBeAsynchronous: true }));
  return { plan, deleted };
}

async function authenticate(json) {
  let account;
  try { account = JSON.parse(json ?? ''); } catch { throw new Error('Missing cleanup service-account configuration'); }
  if (account.project_id !== site || account.type !== 'service_account' ||
      !account.client_email?.endsWith(`@${site}.iam.gserviceaccount.com`) ||
      typeof account.private_key !== 'string') throw new Error('Credential is not for approved project');
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const issued = Math.floor(Date.now() / 1000);
  const claim = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
    iss: account.client_email, scope: 'https://www.googleapis.com/auth/firebase.hosting',
    aud: oauth, iat: issued, exp: issued + 3600,
  })}`;
  const signature = createSign('RSA-SHA256').update(claim).sign(account.private_key, 'base64url');
  const response = await fetch(oauth, { method: 'POST', signal: AbortSignal.timeout(20000),
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${claim}.${signature}` }) });
  if (!response.ok) throw new Error(`Cleanup authentication failed (${response.status})`);
  const token = (await response.json()).access_token;
  if (!token) throw new Error('Cleanup authentication returned no access token');
  return token;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    if (process.argv.slice(2).some(arg => arg !== '--apply-approved-halabessa-archives')) {
      throw new Error('Unknown cleanup argument');
    }
    const token = await authenticate(process.env.FIREBASE_HOSTING_CLEANUP_SA_JSON);
    const request = async (path, method = 'GET') => {
      // Fixed host and site; no credential can be sent to an arbitrary URL.
      if (!path.startsWith(`${root}/`)) throw new Error('Request outside approved Hosting site');
      const response = await fetch(`${api}${path}`, { method,
        headers: { Authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(20000) });
      if (!response.ok) throw new Error(`Hosting ${method} failed (${response.status})`);
      return method === 'DELETE' ? {} : response.json();
    };
    await cleanupArchives(request, { apply: process.argv.includes('--apply-approved-halabessa-archives') });
  } catch (error) {
    // Do not print credentials, OAuth request bodies, or API response bodies.
    console.error(error.message);
    process.exitCode = 1;
  }
}
