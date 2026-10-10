import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { versionWebBuild } from '../../scripts/version-web-build.mjs';
import { decodeManifest, encodeManifest, fingerprintWebArtwork } from '../../scripts/fingerprint-web-artwork.mjs';

test('deploy entrypoints select matching content-addressed app code', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'halabessa-build-test-'));
  try {
    await mkdir(join(directory, 'assets'));
    const bootstrap = '_flutter.buildConfig={"builds":[{"mainJsPath":"main.dart.js"}]};';
    const index = '<script src="flutter_bootstrap.js" async></script>';
    async function build(code) {
      await writeFile(join(directory, 'assets/AssetManifest.bin'), Buffer.from([13, 0]));
      await writeFile(join(directory, 'main.dart.js'), code);
      await writeFile(join(directory, 'flutter_bootstrap.js'), bootstrap);
      await writeFile(join(directory, 'index.html'), index);
      return versionWebBuild(directory);
    }
    const first = await build('version one');
    const second = await build('version two');
    assert.notEqual(first.mainName, second.mainName);
    assert.notEqual(first.bootstrapName, second.bootstrapName);
    assert.equal(await readFile(join(directory, second.mainName), 'utf8'), 'version two');
    assert.match(await readFile(join(directory, second.bootstrapName), 'utf8'), new RegExp(second.mainName));
    assert.match(await readFile(join(directory, 'index.html'), 'utf8'), new RegExp(second.bootstrapName));
    assert.deepEqual(await build('version two'), second);
    await assert.rejects(versionWebBuild(directory), /Unexpected Flutter entrypoint/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('artwork bytes are fingerprinted while logical keys and resolution variants stay intact', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'halabessa-art-test-'));
  try {
    const assets = join(directory, 'assets');
    await mkdir(join(assets, 'assets/images/2.0x'), {recursive: true});
    const key = 'assets/images/حلبسه.png';
    const retina = 'assets/images/2.0x/حلبسه.png';
    const manifest = new Map([[key, [new Map([['asset', key]]),
      new Map([['asset', retina], ['dpr', 2.0]])]],
      ['assets/translations/en-US.json', [new Map([['asset', 'assets/translations/en-US.json']])]]]);
    const bytes = encodeManifest(manifest);
    assert.deepEqual(encodeManifest(decodeManifest(bytes)), bytes);
    await writeFile(join(assets, 'AssetManifest.bin'), bytes);
    await writeFile(join(assets, key), 'original image');
    await writeFile(join(assets, retina), 'retina image');
    assert.equal(await fingerprintWebArtwork(directory), 2);
    const binary = await readFile(join(assets, 'AssetManifest.bin'));
    assert.equal(JSON.parse(await readFile(join(assets, 'AssetManifest.bin.json'), 'utf8')), binary.toString('base64'));
    const decoded = decodeManifest(binary);
    const selected = decoded.get(key);
    const path = selected[0].get('asset');
    assert.match(path, /^_immutable\/[a-f0-9]{64}\/assets\/images\//);
    assert.equal(await readFile(join(assets, path), 'utf8'), 'original image');
    assert.equal(await readFile(join(assets, selected[1].get('asset')), 'utf8'), 'retina image');
    assert.equal(selected[1].get('dpr').value, 2);
    assert.equal(decoded.get('assets/translations/en-US.json')[0].get('asset'), 'assets/translations/en-US.json');
    await writeFile(join(assets, 'AssetManifest.bin'), bytes);
    await writeFile(join(assets, key), 'changed image');
    await fingerprintWebArtwork(directory);
    assert.notEqual(decodeManifest(await readFile(join(assets, 'AssetManifest.bin'))).get(key)[0].get('asset'), path);
    assert.equal(await readFile(join(assets, path), 'utf8'), 'original image');
  } finally {
    await rm(directory, {recursive: true, force: true});
  }
});

test('manifest changes and unsafe paths fail closed; long Unicode strings round trip', async () => {
  for (const length of [260, 70000]) {
    const manifest = new Map([['ح'.repeat(length), []]]);
    assert.deepEqual(decodeManifest(encodeManifest(manifest)), manifest);
  }
  assert.throws(() => decodeManifest(Buffer.from([13, 1])), /Truncated/);
  assert.throws(() => decodeManifest(Buffer.from([8, 0])), /Unsupported/);
  const directory = await mkdtemp(join(tmpdir(), 'halabessa-path-test-'));
  try {
    await mkdir(join(directory, 'assets'));
    const original = encodeManifest(new Map([['image.png', [new Map([['asset', 'assets/../../escape.png']])]]]));
    await writeFile(join(directory, 'assets/AssetManifest.bin'), original);
    await assert.rejects(fingerprintWebArtwork(directory), /Unsafe artwork path/);
    assert.deepEqual(await readFile(join(directory, 'assets/AssetManifest.bin')), original);
  } finally { await rm(directory, {recursive: true, force: true}); }
});
