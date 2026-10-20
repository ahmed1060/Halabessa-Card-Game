import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, access, mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import vm from 'node:vm';
import { versionWebBuild } from '../../scripts/version-web-build.mjs';

const root = new URL('../../', import.meta.url);
const homepage = await readFile(new URL('web/landing.html', root), 'utf8');
const routing = await readFile(new URL('web/landing-route.js', root), 'utf8');
const origin = 'https://halabessa-card-game1.web.app';

test('Google ownership file retains the supplied verification response', async () => {
  const verification = await readFile(new URL('web/google902e70cc206e0f62.html', root), 'utf8');
  assert.equal(verification.trim(), 'google-site-verification: google902e70cc206e0f62.html');
});

test('homepage exposes honest bilingual search content without the app runtime', async () => {
  assert.match(homepage, /<!DOCTYPE html>/);
  assert.match(homepage, /<html lang="ar" dir="rtl">/);
  assert.match(homepage, /<title>Halabessa Card Game \| لعبة حلبسة<\/title>/);
  assert.equal((homepage.match(/<h1\b/g) ?? []).length, 1);
  assert.match(homepage, /<meta name="robots" content="index, follow/);
  assert.match(homepage, /<link rel="canonical" href="https:\/\/halabessa-card-game1\.web\.app\/">/);
  assert.match(homepage, /<section id="english" lang="en" dir="ltr"/);
  assert.match(homepage, /href="play.html"/);
  assert.doesNotMatch(homepage, /flutter_bootstrap|web\.loader|main\.dart|<canvas|userAgent|aggregateRating/);
  const structured = JSON.parse(homepage.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)[1]);
  assert.equal(structured['@type'], 'WebSite');
  assert.equal(structured.url, `${origin}/`);
  assert.equal(structured.name, 'Halabessa');
  assert.ok(structured.alternateName.includes('لعبه حلبسه'));
  const english = homepage.match(/<section id="english"[\s\S]*?<\/section>/)[0];
  for (const name of ['7alabessa', 'halabesa', '7alabesa']) {
    assert.ok(structured.alternateName.includes(name), `${name} is an alternate website name`);
    assert.ok(english.includes(name), `${name} is visible to visitors without running JavaScript`);
  }
  for (const [, path] of homepage.matchAll(/(?:href|src)="([^"#]+)"/g)) {
    if (/^(https?:|mailto:)/.test(path) || path === '/' || path === 'play.html') continue;
    await access(new URL(`web/${path}`, root));
  }
  const png = await readFile(new URL('web/images/halabessa-game-preview.png', root));
  assert.equal(png.readUInt32BE(16), 1506);
  assert.equal(png.readUInt32BE(20), 645);
});

test('discovery files advertise only canonical public pages, not private hash views', async () => {
  const robots = await readFile(new URL('web/robots.txt', root), 'utf8');
  assert.match(robots, /User-agent: \*\s+Allow: \//);
  assert.ok(robots.includes(`Sitemap: ${origin}/sitemap.xml`));
  assert.doesNotMatch(robots, /Disallow:\s*\/\s*$/m);
  const sitemap = await readFile(new URL('web/sitemap.xml', root), 'utf8');
  const urls = [...sitemap.matchAll(/<loc>(.*?)<\/loc>/g)].map(m => m[1]);
  assert.equal(new Set(urls).size, urls.length);
  assert.ok(urls.includes(`${origin}/`));
  for (const url of urls) {
    assert.equal(new URL(url).origin, origin);
    assert.equal(new URL(url).hash, '');
    assert.equal(new URL(url).search, '');
    assert.doesNotMatch(url, /play\.html|landing\.html|account|game$/);
    if (new URL(url).pathname !== '/') await access(new URL(`web${new URL(url).pathname}`, root));
  }
});

for (const [path, expected] of [
  ['/', null],
  ['/?renderer=unity', null],
  ['/#about', null],
  ['/#english', null],
  ['/#/game', '/play.html#/game'],
  ['/?renderer=unity#/game', '/play.html?renderer=unity#/game'],
  ['/#/account/delete', '/play.html#/account/delete'],
  ['/?code=test%2Bvalue#/home', '/play.html?code=test%2Bvalue#/home'],
]) {
  test(`legacy routing preserves destinations and queries for ${path}`, () => {
    const source = new URL(path, origin);
    let destination = null;
    const location = { href: source.href, search: source.search, hash: source.hash,
      replace(value) { destination = value; } };
    vm.runInNewContext(routing, { window: { location }, URL });
    assert.equal(destination, expected === null ? null : `${origin}${expected}`);
  });
}

test('web packaging keeps matching fingerprinted game code beside indexable HTML', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'halabessa-landing-'));
  try {
    await mkdir(join(directory, 'assets'));
    await writeFile(join(directory, 'assets/AssetManifest.bin'), Buffer.from([13, 0]));
    await writeFile(join(directory, 'main.dart.js'), 'verified game code');
    await writeFile(join(directory, 'flutter_bootstrap.js'), '_flutter.buildConfig={"builds":[{"mainJsPath":"main.dart.js"}]};');
    const shell = await readFile(new URL('web/index.html', root), 'utf8');
    await writeFile(join(directory, 'index.html'), shell);
    await writeFile(join(directory, 'landing.html'), homepage);
    const result = await versionWebBuild(directory);
    assert.equal(await readFile(join(directory, 'index.html'), 'utf8'), homepage);
    const playable = await readFile(join(directory, 'play.html'), 'utf8');
    assert.match(playable, new RegExp(result.bootstrapName));
    assert.match(playable, /name="robots" content="noindex, follow"/);
    assert.ok(playable.includes('id="game-host"'));
    assert.ok(playable.includes('initUnityEngine'));
    assert.equal(await readFile(join(directory, result.mainName), 'utf8'), 'verified game code');
    assert.ok((await readFile(join(directory, result.bootstrapName), 'utf8')).includes(result.mainName));
    const firebase = JSON.parse(await readFile(new URL('firebase.json', root), 'utf8'));
    assert.equal(firebase.hosting.rewrites.at(-1).destination, '/play.html');
    const manifest = JSON.parse(await readFile(new URL('web/manifest.json', root), 'utf8'));
    assert.equal(manifest.id, '/');
    assert.equal(manifest.start_url, '/play.html');
    assert.equal(manifest.scope, '/');
    await assert.rejects(versionWebBuild(directory), /Unexpected Flutter entrypoint/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
