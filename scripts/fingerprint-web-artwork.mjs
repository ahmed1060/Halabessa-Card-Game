import { createHash } from 'node:crypto';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, dirname, sep } from 'node:path';

// Flutter's web AssetManifest.bin.json wraps StandardMessageCodec in base64.
// Preserve logical keys and dpr metadata; rewrite only image variant locations.
// This is deliberately a strict manifest codec, not a general platform codec.
class DartNumber {
  constructor(tag, value) { this.tag = tag; this.value = value; }
}

export function decodeManifest(bytes) {
  let offset = 0;
  const take = n => {
    if (offset + n > bytes.length) throw new Error('Truncated asset manifest');
    const found = bytes.subarray(offset, offset + n); offset += n; return found;
  };
  const size = () => {
    const n = take(1)[0];
    return n < 254 ? n : n === 254 ? take(2).readUInt16LE() : take(4).readUInt32LE();
  };
  function value() {
    const tag = take(1)[0];
    switch (tag) {
      case 0: return null;
      case 1: return true;
      case 2: return false;
      case 3: return new DartNumber(tag, take(4).readInt32LE());
      case 4: return new DartNumber(tag, take(8).readBigInt64LE());
      case 6: {
        take((8 - offset % 8) % 8);
        return new DartNumber(tag, take(8).readDoubleLE());
      }
      case 7: return new TextDecoder('utf-8', {fatal: true}).decode(take(size()));
      case 12: return Array.from({length: size()}, value);
      case 13: return new Map(Array.from({length: size()}, () => [value(), value()]));
      default: throw new Error(`Unsupported asset manifest type ${tag}`);
    }
  }
  const result = value();
  if (offset !== bytes.length || !(result instanceof Map)) throw new Error('Invalid asset manifest');
  return result;
}

export function encodeManifest(manifest) {
  const parts = []; let offset = 0;
  const put = bytes => { parts.push(bytes); offset += bytes.length; };
  const byte = n => put(Buffer.from([n]));
  const size = n => {
    if (n < 254) byte(n);
    else { byte(n <= 65535 ? 254 : 255); const b = Buffer.alloc(n <= 65535 ? 2 : 4);
      if (b.length === 2) b.writeUInt16LE(n); else b.writeUInt32LE(n); put(b); }
  };
  function value(v) {
    if (v == null) byte(0);
    else if (typeof v === 'boolean') byte(v ? 1 : 2);
    else if (v instanceof DartNumber || typeof v === 'number') {
      const tag = v instanceof DartNumber ? v.tag : 6;
      const number = v instanceof DartNumber ? v.value : v;
      byte(tag);
      if (tag === 6) put(Buffer.alloc((8 - offset % 8) % 8));
      const b = Buffer.alloc(tag === 3 ? 4 : 8);
      if (tag === 3) b.writeInt32LE(number);
      else if (tag === 4) b.writeBigInt64LE(number);
      else b.writeDoubleLE(number);
      put(b);
    } else if (typeof v === 'string') {
      byte(7); const b = Buffer.from(v, 'utf8'); size(b.length); put(b);
    } else if (Array.isArray(v)) {
      byte(12); size(v.length); v.forEach(value);
    } else if (v instanceof Map) {
      byte(13); size(v.size); for (const [key, entry] of v) {value(key); value(entry);}
    } else throw new Error('Unsupported asset manifest value');
  }
  value(manifest); return Buffer.concat(parts);
}

export async function fingerprintWebArtwork(directory) {
  const assets = resolve(directory, 'assets');
  const original = await readFile(resolve(assets, 'AssetManifest.bin'));
  const manifest = decodeManifest(original);
  // Fail before modifying anything if the SDK's encoding changed.
  if (!encodeManifest(manifest).equals(original)) throw new Error('Asset manifest codec changed');
  const changes = new Map();
  for (const [logicalKey, variants] of manifest) {
    if (typeof logicalKey !== 'string' || !Array.isArray(variants)) throw new Error('Invalid asset variants');
    for (const variant of variants) {
      const path = variant instanceof Map ? variant.get('asset') : null;
      if (typeof path !== 'string') throw new Error('Invalid asset variant');
      if (!/\.(png|jpe?g|webp|gif|avif)$/i.test(path)) continue;
      if (!/^(assets|packages)\//.test(path) || path.includes('\\') || path.split('/').some(p => p === '..' || !p)) {
        throw new Error('Unsafe artwork path');
      }
      const source = resolve(assets, path);
      if (!source.startsWith(assets + sep)) throw new Error('Unsafe artwork path');
      if (!changes.has(path)) {
        const bytes = await readFile(source);
        const hash = createHash('sha256').update(bytes).digest('hex');
        changes.set(path, {bytes, name: `_immutable/${hash}/${path}`});
      }
      variant.set('asset', changes.get(path).name);
    }
  }
  for (const {bytes, name} of changes.values()) {
    const target = resolve(assets, name);
    await mkdir(dirname(target), {recursive: true}); await writeFile(target, bytes);
  }
  const updated = encodeManifest(manifest);
  await writeFile(resolve(assets, 'AssetManifest.bin'), updated);
  await writeFile(resolve(assets, 'AssetManifest.bin.json'), JSON.stringify(updated.toString('base64')));
  // Originals remain revalidated for rootBundle/direct URLs and older clients.
  return changes.size;
}
