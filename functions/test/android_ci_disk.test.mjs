import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

test('Android CI prepares disk before checkout with a fixed, guarded SDK allowlist', async () => {
  const workflow = await readFile(new URL('../../.github/workflows/android-build.yml', import.meta.url), 'utf8');
  const preparation = workflow.slice(workflow.indexOf('- name: Prepare Android runner disk space'), workflow.indexOf('- uses: actions/checkout@v4'));
  assert.ok(preparation.length > 0, 'Disk preparation must precede checkout and build tool installation');
  assert.match(preparation, /for target in \/usr\/share\/dotnet \/opt\/ghc \/usr\/local\/share\/boost \/opt\/hostedtoolcache\/CodeQL; do/);
  assert.match(preparation, /\[\[ ! -L "\$target" && "\$\(realpath -- "\$target"\)" == "\$target" \]\] \|\| exit 1/);
  assert.match(preparation, /sudo rm -rf -- "\$target"/);
  assert.match(preparation, /available_kib < 12 \* 1024 \* 1024/);
  assert.doesNotMatch(preparation, /rm[^\n]*(?:ANDROID|JAVA|FLUTTER|RUNNER|GITHUB|\/usr\/local\/lib\/android)/);
  assert.match(workflow, /node --test[^\n]+functions\/test\/android_ci_disk.test.mjs/);
});
