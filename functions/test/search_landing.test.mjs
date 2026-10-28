import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, access, mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { versionWebBuild } from '../../scripts/version-web-build.mjs';

const root = new URL('../../', import.meta.url);
const homepage = await readFile(new URL('web/index.html', root), 'utf8');
const origin = 'https://halabessa-card-game1.web.app';

test('Google ownership file retains the supplied verification response', async () => {
  const verification = await readFile(new URL('web/google902e70cc206e0f62.html', root), 'utf8');
  assert.equal(verification.trim(), 'google-site-verification: google902e70cc206e0f62.html');
});

test('root opens the game directly while keeping canonical metadata', async () => {
  assert.match(homepage, /<title>Halabessa Card Game \| لعبة حلبسة<\/title>/);
  assert.match(homepage, /<meta name="robots" content="index, follow/);
  assert.ok(homepage.includes('<link rel="canonical" href="'+origin+'/">'));
  assert.match(homepage, /id="game-host"/);
  assert.match(homepage, /src="flutter_bootstrap\.js"/);
  assert.doesNotMatch(homepage, /landing-route|landing\.css|class="hero"|class="play-button"/);
  await assert.rejects(access(new URL('web/landing.html', root)));
  const structured = JSON.parse(homepage.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)[1]);
  assert.equal(structured.url, origin+'/');
  assert.equal(structured.name, 'Halabessa');
  const fallback = homepage.match(/<noscript>([\s\S]*?)<\/noscript>/)[1];
  for (const name of ['7alabessa', 'halabesa', '7alabesa', 'لعبه حلبسه']) {
    assert.ok(structured.alternateName.includes(name));
  }
  assert.match(fallback, /Enable JavaScript/);
  assert.match(fallback, /lang="ar" dir="rtl"/);
  assert.doesNotMatch(homepage, /userAgent|aggregateRating/);
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

test('root and play links select matching game code without a landing detour', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'halabessa-landing-'));
  try {
    await mkdir(join(directory, 'assets'));
    await writeFile(join(directory, 'assets/AssetManifest.bin'), Buffer.from([13, 0]));
    await writeFile(join(directory, 'main.dart.js'), 'verified game code');
    await writeFile(join(directory, 'flutter_bootstrap.js'), '_flutter.buildConfig={"builds":[{"mainJsPath":"main.dart.js"}]};');
    const shell = await readFile(new URL('web/index.html', root), 'utf8');
    await writeFile(join(directory, 'index.html'), shell);
    const result = await versionWebBuild(directory);
    const index = await readFile(join(directory, 'index.html'), 'utf8');
    assert.ok(index.includes(result.bootstrapName));
    assert.match(index, /name="robots" content="index, follow/);
    assert.ok(index.includes('id="game-host"'));
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
