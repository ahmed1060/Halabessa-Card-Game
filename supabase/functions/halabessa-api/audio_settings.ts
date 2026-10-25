// Narrow, server-only bridge for the existing Firestore audio documents.
// Authentication/active-account/admin admission must run before any store I/O.
import { assertActiveIdentity, type FirebaseIdentity } from './firebase_identity.ts';

export async function authorizeAudioSettings(user: {uid: string; authTime: unknown},
  lookup: (uid: string) => Promise<FirebaseIdentity | null>,
  admit: (actor: {uid: string; email: string | null}) => Promise<boolean>) {
  const account = await lookup(user.uid);
  assertActiveIdentity(account, user.authTime);
  // Do not trust a stale JWT email or any client-supplied admin boolean.
  if (!await admit({uid: user.uid, email: account!.email})) throw new Error('admin_required');
}

export type AudioSettingInput = { operation?: unknown; assetKey?: unknown; kind?: unknown; url?: unknown };
type Fields = Record<string, any>;
type Slot = { id: string; assetKey: string; kind: string; storageKind: string };
const sfx = new Set(['capture', 'deal', 'play', 'pick', 'return', 'reveal',
  'slam_0', 'slam_1', 'slam_2', 'shuffle', 'cut', 'win', 'lose', 'purchase'].map(key => `sfx/${key}.mp3`));
const operations = new Set(['replace', 'saveDefault', 'restoreSaved', 'restoreBundled']);

export function audioSettingSlot(input: AudioSettingInput): Slot {
  const key = input.assetKey;
  if (input.kind === 'sfx' && typeof key === 'string' && sfx.has(key)) {
    return { id: `sfx_${key.replaceAll('/', '_')}`, assetKey: key, kind: 'sfx', storageKind: 'sfx' };
  }
  if (input.kind === 'music' && key === 'music/bg_music.mp3') {
    return { id: 'music', assetKey: key, kind: 'music', storageKind: 'music' };
  }
  if (input.kind === 'room_music' && key === 'music/room_music.mp3') {
    return { id: 'room_music', assetKey: key, kind: 'room_music', storageKind: 'music' };
  }
  throw new Error('invalid_audio_setting');
}

export function immutableAudioUrl(slot: Slot, value: unknown, storageUrl: string): string {
  if (typeof value !== 'string' || value.length > 2048) throw new Error('invalid_audio_setting');
  const base = new URL(storageUrl);
  const key = slot.assetKey.replace(/[^a-zA-Z0-9_-]+/g, '-').replace(/^-+|-+$/g, '');
  const prefix = `${base.origin}/storage/v1/object/public/game-assets/audio/${slot.storageKind}/${key}/v2/`;
  if (base.protocol !== 'https:' || !value.startsWith(prefix) ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(wav|mp3|m4a)$/.test(value.slice(prefix.length))) {
    throw new Error('invalid_audio_setting');
  }
  return value;
}

export type AudioSettingsStore = {
  replace(slot: Slot, url: string): Promise<void>;
  restoreBundled(slot: Slot): Promise<void>;
  copy(slot: Slot, backup: boolean): Promise<boolean>;
};

export async function updateAudioSetting(input: AudioSettingInput, dependencies: {
  authorize: () => Promise<void>;
  store: AudioSettingsStore;
  storageUrl: string;
  fetch?: typeof fetch;
}) {
  await dependencies.authorize();
  const slot = audioSettingSlot(input);
  if (typeof input.operation !== 'string' || !operations.has(input.operation) ||
      (input.operation !== 'replace' && input.url !== undefined)) throw new Error('invalid_audio_setting');
  if (input.operation === 'replace') {
    const url = immutableAudioUrl(slot, input.url, dependencies.storageUrl);
    let response: Response;
    try {
      response = await (dependencies.fetch ?? fetch)(url, {
        method: 'HEAD', redirect: 'error', signal: AbortSignal.timeout(5000),
      });
    } catch { throw new Error('audio_asset_unavailable'); }
    const size = Number(response.headers.get('content-length'));
    const mime = response.headers.get('content-type')?.split(';')[0];
    const extension = url.split('.').at(-1);
    const expected = extension === 'wav' ? 'audio/wav' : extension === 'mp3' ? 'audio/mpeg' : 'audio/mp4';
    if (!response.ok || !Number.isSafeInteger(size) || size <= 0 || size > 4 * 1024 * 1024 || mime !== expected) {
      throw new Error('audio_asset_unavailable');
    }
    await dependencies.store.replace(slot, url);
    return { ok: true };
  }
  if (input.operation === 'restoreBundled') {
    await dependencies.store.restoreBundled(slot);
    return { ok: true };
  }
  const copied = await dependencies.store.copy(slot, input.operation === 'saveDefault');
  if (!copied && input.operation === 'saveDefault') throw new Error('audio_override_missing');
  return { ok: true, copied };
}

/** Uses the existing server OAuth token; never accepts client document paths. */
export function createAudioSettingsStore(project: string, token: () => Promise<string>, fetcher = fetch): AudioSettingsStore {
  if (!/^[a-z][a-z0-9-]{4,62}$/.test(project)) throw new Error('invalid_audio_project');
  const base = `projects/${project}/databases/(default)/documents`;
  const endpoint = `https://firestore.googleapis.com/v1/${base}`;
  function name(slot: Slot, backup = false) {
    // Revalidate even when this adapter is used independently of the HTTP route.
    const expected = audioSettingSlot(slot);
    if (expected.id !== slot.id) throw new Error('invalid_audio_setting');
    return `${base}/settings/global/overrides/${slot.id}${backup ? '_backup' : ''}`;
  }
  async function request(path: string, method: string, body?: unknown) {
    let response: Response;
    try {
      response = await fetcher(`${endpoint}${path}`, {
        method, signal: AbortSignal.timeout(5000),
        headers: { Authorization: `Bearer ${await token()}`, 'Content-Type': 'application/json' },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
    } catch { throw new Error('audio_store_unavailable'); }
    let data: any;
    try { data = await response.json(); } catch { throw new Error('audio_store_unavailable'); }
    return { response, data };
  }
  function success(result: {response: Response; data: any}) {
    if (!result.response.ok) throw new Error(result.data?.error?.status === 'ABORTED' ? 'audio_transaction_conflict' : 'audio_store_unavailable');
    return result.data;
  }
  async function commit(writes: unknown[], transaction?: string) {
    success(await request(':commit', 'POST', { writes, ...(transaction ? { transaction } : {}) }));
  }
  async function rollback(transaction: string) {
    try { await request(':rollback', 'POST', { transaction }); } catch { /* Preserve the original failure. */ }
  }
  return {
    async replace(slot, url) {
      const fields: Fields = { url: { stringValue: url } };
      if (slot.kind === 'sfx') fields.assetPath = { stringValue: slot.assetKey };
      await commit([{ update: { name: name(slot), fields } }]);
    },
    async restoreBundled(slot) { await commit([{ delete: name(slot) }]); },
    async copy(slot, backup) {
      const source = name(slot, !backup), target = name(slot, backup);
      for (let attempt = 0; attempt < 3; attempt++) {
        const started = success(await request(':beginTransaction', 'POST', {}));
        const transaction = started?.transaction;
        if (typeof transaction !== 'string' || !transaction) throw new Error('audio_store_unavailable');
        let committed = false;
        try {
          const read = success(await request(':batchGet', 'POST', { documents: [source], transaction }));
          const rows = Array.isArray(read) ? read : [read];
          if (rows.length !== 1 || !rows[0] ||
              !((rows[0].missing === source && !rows[0].found) ||
                (rows[0].found?.name === source && !rows[0].missing))) throw new Error('audio_store_unavailable');
          if (rows[0].missing === source) {
            if (!backup) { await commit([{ delete: target }], transaction); committed = true; }
            return false;
          }
          const fields = rows[0].found.fields;
          if (typeof fields?.url?.stringValue !== 'string' || !fields.url.stringValue) throw new Error('audio_store_unavailable');
          // The source is an existing admin-written document: preserve legacy
          // saved URLs/metadata without fetching them or accepting stale UI data.
          await commit([{ update: { name: target, fields: { ...fields, isBackup: { booleanValue: backup } } } }], transaction);
          committed = true;
          return true;
        } catch (error) {
          if (!(error instanceof Error && error.message === 'audio_transaction_conflict') || attempt === 2) throw error;
        } finally {
          if (!committed) await rollback(transaction);
        }
      }
      throw new Error('audio_transaction_conflict');
    },
  };
}
