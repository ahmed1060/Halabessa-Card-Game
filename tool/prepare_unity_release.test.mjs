import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { brotliCompressSync } from 'node:zlib';
import { prepare, verify } from './prepare_unity_release.mjs';

const repo = fileURLToPath(new URL('..', import.meta.url));
const markers = 'REQUEST_READY UNITY_VIEWPORT_CHANGED UNITY_CARD_FEEL_READY VISUAL_CONTACT VISUAL_ACTION_COMPLETE';
const androidMetadata = 'android/unityLibrary/src/main/assets/bin/Data/Managed/Metadata/global-metadata.dat';
const iosMetadata = 'ios/Data/Managed/Metadata/global-metadata.dat';
async function put(root, name, bytes) {
  await fs.mkdir(path.dirname(path.join(root, name)), { recursive: true });
  await fs.writeFile(path.join(root, name), bytes);
}
async function fixture() {
  // Keep tiny fixtures in ignored build/; never delete an arbitrary directory.
  const root = await fs.mkdtemp(path.join(repo, 'build/unity-staging-test-'));
  const input = path.join(root, 'build/export');
  const output = path.join(root, 'build/candidate');
  for (const tree of ['Assets', 'ProjectSettings', 'Packages']) {
    await put(root, `unity/Halabessa/${tree}/source.txt`, 'original\r\n');
  }
  for (const [folder, target] of [['android', 'Android'], ['ios', 'iOS'], ['web', 'WebGL']]) {
    await put(input, `${folder}-export.json`, JSON.stringify({
      target, result: 'Succeeded', errors: 0, warnings: 0, output: path.join(input, folder),
    }));
  }
  for (const name of [androidMetadata, iosMetadata]) await put(input, name, markers);
  const elf = Buffer.alloc(64);
  Buffer.from('7f454c460201', 'hex').copy(elf);
  elf.writeUInt16LE(183, 18);
  for (const name of ['libmain.so', 'libunity.so', 'libil2cpp.so']) {
    await put(input, `android/unityLibrary/src/main/jniLibs/arm64-v8a/${name}`, elf);
  }
  for (const dir of ['cpp', 'java', 'res', 'resources']) {
    await put(input, `android/unityLibrary/src/main/${dir}/file.txt`, dir);
  }
  await put(input, 'android/unityLibrary/src/main/AndroidManifest.xml', '<manifest/>');
  await put(input, 'android/unityLibrary/libs/classes.jar', 'jar');
  await put(input, 'android/unityLibrary/proguard-unity.txt', '# rules');
  await put(input, 'android/unityLibrary/build.gradle', 'ndkPath "C:/local/editor"');
  await put(input, 'android/unityLibrary/build/cache', 'exclude me');
  await put(input, 'android/unityLibrary/src/main/Il2CppOutputProject/il2cpp.exe', 'exclude me');
  for (const name of ['unityLibrary/build.gradle', 'shared/keepUnitySymbols.gradle']) {
    await put(root, `androidBuild/unityExport/${name}`, '// portable integration');
  }
  await put(input, 'ios/Libraries/libiPhone-lib.a', '!<arch>\n');
  await put(input, 'ios/Unity-iPhone.xcodeproj/project.pbxproj', '// project');
  await put(input, 'web/Build/web.wasm.unityweb', brotliCompressSync(Buffer.from('0061736d01000000', 'hex')));
  await put(input, 'web/Build/web.data.unityweb', brotliCompressSync(Buffer.from(markers)));
  await put(input, 'web/Build/web.framework.js.unityweb', 'framework');
  await put(input, 'web/Build/web.loader.js', 'loader');
  for (const name of ['web.data.unityweb', 'web.wasm.unityweb', 'web.framework.js.unityweb', 'web.loader.js']) {
    await put(root, `web/Build/${name}`, 'old shipping');
  }
  await put(root, androidMetadata.replace('android/', 'androidBuild/unityExport/'), 'old shipping');
  await put(root, iosMetadata.replace('ios/', 'ios/UnityLibrary/'), 'old shipping');
  return { root, input, output };
}

test('stages qualified players without modifying shipping integration or copying caches/toolchains', async () => {
  const f = await fixture();
  const result = await prepare(f.root, f.input, f.output);
  assert.equal(result.releaseReady, false);
  assert.equal(result.sourceFiles, 3);
  assert.equal(result.shippingMatches.android, false);
  await verify(f.root, f.output);
  await put(f.output, 'android/unityLibrary/.cxx/local/build.ninja', 'local build cache');
  await verify(f.root, f.output);
  assert.equal(await fs.readFile(path.join(f.output, 'android/unityLibrary/build.gradle'), 'utf8'), '// portable integration');
  assert.equal(await fs.readFile(path.join(f.root, 'web/Build/web.loader.js'), 'utf8'), 'old shipping');
  await assert.rejects(fs.access(path.join(f.output, 'android/unityLibrary/build/cache')));
  await assert.rejects(fs.access(path.join(f.output, 'android/unityLibrary/src/main/Il2CppOutputProject')));
  await assert.rejects(prepare(f.root, f.input, f.output), /EEXIST/);
});

test('rejects failed reports, stale native metadata and stale WebGL data before staging', async () => {
  for (const bad of ['report', 'native', 'web']) {
    const f = await fixture();
    if (bad === 'report') {
      const file = path.join(f.input, 'ios-export.json');
      const report = JSON.parse(await fs.readFile(file, 'utf8'));
      await fs.writeFile(file, JSON.stringify({ ...report, errors: 1 }));
    } else if (bad === 'native') await put(f.input, androidMetadata, 'old');
    else await put(f.input, 'web/Build/web.data.unityweb', brotliCompressSync(Buffer.from('old')));
    await assert.rejects(prepare(f.root, f.input, f.output), /Unqualified|Stale/);
    await assert.rejects(fs.access(f.output));
  }
});

test('rejects unresolved LFS pointers instead of accepting placeholder binaries', async () => {
  const f = await fixture();
  await put(f.input, 'android/unityLibrary/libs/classes.jar', 'version https://git-lfs.github.com/spec/v1\n');
  await assert.rejects(prepare(f.root, f.input, f.output), /Unresolved Git LFS/);
  await assert.rejects(fs.access(path.join(f.output, 'unity-release-manifest.json')));
});

test('verification detects changed source and changed player bytes', async () => {
  for (const source of [true, false]) {
    const f = await fixture();
    await prepare(f.root, f.input, f.output);
    if (source) await put(f.root, 'unity/Halabessa/Assets/source.txt', 'changed');
    else await put(f.output, 'web/Build/web.loader.js', 'changed');
    await assert.rejects(verify(f.root, f.output), /source changed|payload changed/);
  }
});

test('normalizes source line endings across build hosts', async () => {
  const f = await fixture();
  await prepare(f.root, f.input, f.output);
  await put(f.root, 'unity/Halabessa/Assets/source.txt', 'original\n');
  await verify(f.root, f.output);
});

test('records an unresolved Windows symbol-tool path as an iOS release gate', async () => {
  const f = await fixture();
  await put(f.input, 'ios/Unity-iPhone.xcodeproj/project.pbxproj', '--usymtool-path=C:/Unity/Tools/usymtool.exe');
  const result = await prepare(f.root, f.input, f.output);
  assert.equal(result.portability.iosWindowsSymbolToolArgument, true);
  const manifest = JSON.parse(await fs.readFile(path.join(f.output, 'unity-release-manifest.json')));
  assert.ok(manifest.gates.some(g => g.includes('Windows exporter')));
});

test('refuses staging outside ignored build or inside the input export', async () => {
  const f = await fixture();
  await assert.rejects(prepare(f.root, f.input, path.join(f.root, 'shipping')), /inside build/);
  await assert.rejects(prepare(f.root, f.input, path.join(f.input, 'nested')), /separate/);
  await assert.rejects(fs.access(path.join(f.root, 'shipping')));
});
