import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { versionWebBuild } from '../../scripts/version-web-build.mjs';

test('deploy entrypoints select matching content-addressed app code', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'halabessa-build-test-'));
  try {
    const bootstrap = '_flutter.buildConfig={"builds":[{"mainJsPath":"main.dart.js"}]};';
    const index = '<script src="flutter_bootstrap.js" async></script>';
    async function build(code) {
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
