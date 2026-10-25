import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {brotliDecompressSync} from 'node:zlib';

const root = new URL('../../', import.meta.url);
const read = path => readFileSync(new URL(path, root));
const text = path => read(path).toString('utf8');
const manifest = JSON.parse(text('web/unity-release.json'));

test('shipping Unity loader, data, framework and WASM match the reviewed release', () => {
  for (const [path, hash] of Object.entries(manifest.files)) {
    assert.equal(createHash('sha256').update(read(`web/${path}`)).digest('hex'), hash, path);
  }
  for (const [path, hash] of Object.entries(manifest.sources)) {
    // Git normalizes text in Linux CI; source identity must ignore checkout EOLs.
    assert.equal(createHash('sha256').update(text(path).replace(/\r\n/g, '\n')).digest('hex'), hash, path);
  }
  const wasm = brotliDecompressSync(read('web/Build/web.wasm.unityweb'));
  assert.deepEqual([...wasm.subarray(0,4)], [0,97,115,109]);
  assert.equal(WebAssembly.validate(wasm), true);
});

test('loader and every Unity payload use one stable release identity', () => {
  const html = text('web/index.html');
  assert.ok(html.includes(`src="Build/web.loader.js?v=${manifest.id}"`));
  assert.ok(html.includes(`var cacheBuster = "?v=${manifest.id}";`));
  for (const name of ['web.data.unityweb', 'web.framework.js.unityweb', 'web.wasm.unityweb']) {
    assert.ok(html.includes(`/${name}" + cacheBuster`), name);
  }
  assert.equal(html.includes('"?v=" + Date.now()'), false);
});

test('Hosting enables the tested online web policy without altering native release defaults', () => {
  const hosting = text('.github/workflows/firebase-hosting-merge.yml');
  const build = hosting.slice(hosting.indexOf('flutter build web --release'));
  for (const flag of ['HALABESSA_CARD_INTERACTIONS', 'HALABESSA_CARD_UI_REFINEMENTS',
    'HALABESSA_ONLINE_CARD_INTERACTIONS']) {
    assert.ok(build.includes(`--dart-define=${flag}=true`), flag);
  }
  assert.ok(hosting.includes('test/card_interaction_policy_test.dart'));
  for (const workflow of ['android-build.yml','ios-build.yml']) {
    assert.equal(text(`.github/workflows/${workflow}`).includes(
      '--dart-define=HALABESSA_ONLINE_CARD_INTERACTIONS=true'), false);
  }
  for (const path of ['pages/game_board_screen.dart', 'providers/unity_communication_service.dart']) {
    assert.ok(text(`lib/features/game/presentation/${path}`).includes('cardInteractionsFor('));
    assert.equal(text(`lib/features/game/presentation/${path}`).includes('_cardInteractionsPreview'), false);
  }
});
