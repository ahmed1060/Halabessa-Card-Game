import { assertAvatarUpload } from './avatar_upload_policy.ts';

export type AssetUploadBody = {
  kind?: unknown; contentType?: unknown; base64?: unknown; assetKey?: unknown;
};
export type AssetUploadDependencies = {
  supabaseUrl: string | undefined;
  serviceRoleKey: string | undefined;
  privileged: boolean; // Set only after the existing verified admin admission.
  fetch?: typeof fetch;
  versionId?: () => string;
};
const bucket = 'game-assets';
const extensions = new Map([
  ['image/jpeg','jpg'],['image/png','png'],['image/webp','webp'],
  ['audio/mpeg','mp3'],['audio/wav','wav'],['audio/mp4','m4a'],
]);
const sfxKeys = new Set([
  'capture','deal','play','pick','return','reveal','slam_0','slam_1','slam_2',
  'shuffle','cut','win','lose','purchase',
].map(key => `sfx/${key}.mp3`));
const musicKeys = new Set(['music/bg_music.mp3','music/room_music.mp3']);
function safeKey(value: unknown) {
  return typeof value === 'string'
    ? value.replace(/[^a-zA-Z0-9_-]+/g,'-').replace(/^-+|-+$/g,'').slice(0,80) : '';
}
function decode(value: unknown, maximum: number) {
  if (typeof value !== 'string' || value.length === 0 || value.length > Math.ceil(maximum*4/3)+8) {
    throw new Error('invalid_asset');
  }
  try {
    const binary = atob(value);
    if (!binary.length || binary.length > maximum) throw new Error('invalid_asset');
    return Uint8Array.from(binary, character => character.charCodeAt(0));
  } catch { throw new Error('invalid_asset'); }
}
function assertAudioHeader(bytes: Uint8Array, type: string) {
  const tag = (at: number, value: string) => [...value].every((c,i) => bytes[at+i] === c.charCodeAt(0));
  const valid = type === 'audio/wav' ? bytes.length >= 44 && tag(0,'RIFF') && tag(8,'WAVE')
    : type === 'audio/mp4' ? bytes.length >= 12 && tag(4,'ftyp')
    : type === 'audio/mpeg' && bytes.length >= 10 && (tag(0,'ID3') || (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0));
  // Container sniffing rejects obvious mislabeled input; it does not certify
  // full codec decodability. The isolated preview reports actual decode errors.
  if (!valid) throw new Error('invalid_asset');
}

/** Trusted upload operation, injectable only for local transport tests. */
export async function storeAsset(body: AssetUploadBody, user: {uid: string}, dependencies: AssetUploadDependencies) {
  if (body.kind !== 'avatar' && !dependencies.privileged) throw new Error('admin_required');
  if (typeof body.kind !== 'string' || !['avatar','storeItem','music','sfx'].includes(body.kind) ||
      typeof body.contentType !== 'string' || !extensions.has(body.contentType)) throw new Error('invalid_asset');
  assertAvatarUpload(body.kind,body.contentType,user.uid);
  const audio = body.kind === 'music' || body.kind === 'sfx';
  if (audio && (typeof body.assetKey !== 'string' ||
      !(body.kind === 'music' ? musicKeys : sfxKeys).has(body.assetKey))) throw new Error('invalid_asset');
  if (audio && !body.contentType.startsWith('audio/')) throw new Error('invalid_asset');
  const bytes = decode(body.base64, (body.kind === 'avatar' ? 2 : 4)*1024*1024);
  if (audio) assertAudioHeader(bytes,body.contentType);
  const extension = extensions.get(body.contentType)!;
  const version = body.kind === 'avatar' ? '' : (dependencies.versionId ?? (() => crypto.randomUUID()))();
  if (body.kind !== 'avatar' && !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(version)) {
    throw new Error('invalid_asset');
  }
  const path = body.kind === 'avatar' ? `avatars/${safeKey(user.uid)}/profile.${extension}`
    : body.kind === 'storeItem' ? `store-items/${version}.${extension}`
    : `audio/${body.kind}/${safeKey(body.assetKey)}/v2/${version}.${extension}`;
  const {supabaseUrl,serviceRoleKey} = dependencies;
  if (!supabaseUrl || !serviceRoleKey) throw new Error('storage_not_configured');
  const objectPath = path.split('/').map(encodeURIComponent).join('/');
  const response = await (dependencies.fetch ?? fetch)(`${supabaseUrl}/storage/v1/object/${bucket}/${objectPath}`, {
    method:'POST', signal:AbortSignal.timeout(12_000),
    headers:{Authorization:`Bearer ${serviceRoleKey}`, apikey:serviceRoleKey,
      'Content-Type':body.contentType, 'cache-control':audio ? '31536000' : '3600',
      'x-upsert':audio ? 'false' : 'true'},
    body:bytes,
  });
  // Never retry an audio collision as upsert: an already saved file must survive.
  if (!response.ok) throw new Error('asset_upload_failed');
  return {path,publicUrl:`${supabaseUrl}/storage/v1/object/public/${bucket}/${objectPath}`};
}
