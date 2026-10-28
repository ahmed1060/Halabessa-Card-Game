import test from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { brotliCompressSync } from 'node:zlib';
import { digest, normalizeIosProject, shippingPath } from './integrate_unity_release.mjs';
import { verifyIosIntegration, verifyUnityPlayers } from './verify_unity_players.mjs';

const project = 'path = Data; sourceTree = "<group>"; name = UnityFramework; 9D25AB9C213FB47800354C27 /* UnityFramework */ = { isa = PBXNativeTarget; };';
const scheme = '<BuildAction><BuildableReference BlueprintIdentifier="9D25AB9C213FB47800354C27" BlueprintName="UnityFramework" ReferencedContainer="container:UnityLibrary/Unity-iPhone.xcodeproj"/></BuildAction>' +
  '<LaunchAction><BuildableReference BuildableName="Runner.app"/></LaunchAction>';
const podfile = "target 'Runner' do\nend";

test('removes only the unused Windows symbol-tool option from the exported Xcode phase', () => {
  const before = `${project} --compile-cpp --usymtool-path=\\"C:/Unity/Tools/usymtool.exe\\" --configuration=\\"Release\\"`;
  assert.equal(normalizeIosProject(before), `${project} --compile-cpp --configuration=\\"Release\\"`);
  assert.throws(() => normalizeIosProject(`${before} --generate-usym-file`), /qualified Mac tool/);
  assert.throws(() => normalizeIosProject(before.replace('path = Data', 'path = D:/Data')), /machine-specific/);
  assert.throws(() => normalizeIosProject(project), /exactly one/);
});

test('new integration requires Flutter launch and a separately built Unity framework with no Firebase dependency', () => {
  verifyIosIntegration(podfile, scheme, project);
  assert.throws(() => verifyIosIntegration(`${podfile}\ntarget 'UnityFramework' do`, scheme, project), /Firebase/);
  assert.throws(() => verifyIosIntegration(podfile, scheme, `${project} FirebaseCppApp.a`), /Firebase/);
  assert.throws(() => verifyIosIntegration(podfile, scheme, `${project} --usymtool-path=C:/Unity`), /Machine-specific/);
  assert.throws(() => verifyIosIntegration(podfile, scheme.replace('BlueprintName="UnityFramework"', 'BlueprintName="Removed"'), project), /explicitly build/);
  assert.throws(() => verifyIosIntegration(podfile, scheme.replace('BuildableName="Runner.app"', 'BuildableName="Unity-iPhone.app"'), project), /launcher/);
  assert.throws(() => verifyIosIntegration(podfile, scheme.replace('9D25AB9C213FB47800354C27', '000000000000000000000000'), project), /missing.*target/);
});

test('payload text hashes survive checkout line ending conversion; binary changes fail identity', () => {
  assert.equal(digest(Buffer.from('one\r\ntwo\r\n'), 'generated.cpp'), digest(Buffer.from('one\ntwo\n'), 'generated.cpp'));
  assert.equal(digest(Buffer.from('%YAML 1.1\r\ncontroller: value\r\n'), 'demo.controller'), digest(Buffer.from('%YAML 1.1\ncontroller: value\n'), 'demo.controller'));
  for (const name of ['bridge.jslib', 'Documentation.XML']) {
    assert.equal(digest(Buffer.from('one\r\ntwo\r\n'), name), digest(Buffer.from('one\ntwo\n'), name));
  }
  assert.notEqual(digest(Buffer.from([0, 13, 10]), 'player.so'), digest(Buffer.from([0, 10]), 'player.so'));
});

test('payload mapping is limited to the three named integration roots', () => {
  assert.equal(shippingPath('android/unityLibrary/libs/unity-classes.jar'), 'androidBuild/unityExport/unityLibrary/libs/unity-classes.jar');
  assert.equal(shippingPath('ios/Data/Managed/Metadata/global-metadata.dat'), 'ios/UnityLibrary/Data/Managed/Metadata/global-metadata.dat');
  assert.equal(shippingPath('web/Build/web.loader.js'), 'web/Build/web.loader.js');
  assert.throws(() => shippingPath('other/anything'), /Unexpected/);
});

async function fixture() {
  await fs.mkdir(fileURLToPath(new URL('../build/', import.meta.url)), { recursive: true });
  const root = await fs.mkdtemp(path.join(fileURLToPath(new URL('../build/', import.meta.url)), 'integrated-player-test-'));
  const write = async (name, bytes) => {
    await fs.mkdir(path.dirname(path.join(root, name)), { recursive: true });
    await fs.writeFile(path.join(root, name), bytes);
  };
  const sources = {};
  for (const tree of ['Assets', 'Packages', 'ProjectSettings']) {
    const name = `unity/Halabessa/${tree}/sample.cs`;
    await write(name, 'original\r\n');
    sources[name] = digest(Buffer.from('original\n'), name);
  }
  const markers = Buffer.from('REQUEST_READY UNITY_VIEWPORT_CHANGED UNITY_CARD_FEEL_READY VISUAL_CONTACT VISUAL_ACTION_COMPLETE');
  const payloads = { android: {}, ios: {}, web: {} };
  for (const [target, name, bytes] of [
    ['android', 'androidBuild/unityExport/unityLibrary/src/main/assets/bin/Data/Managed/Metadata/global-metadata.dat', markers],
    ['ios', 'ios/UnityLibrary/Data/Managed/Metadata/global-metadata.dat', markers],
    ['ios', 'ios/UnityLibrary/Unity-iPhone.xcodeproj/project.pbxproj', Buffer.from(project)],
    ['web', 'web/Build/web.data.unityweb', brotliCompressSync(markers)],
  ]) {
    await write(name, bytes);
    payloads[target][name] = digest(bytes, name);
  }
  await write('ios/Podfile', podfile);
  await write('ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme', scheme);
  await write('unity/player-release.json', JSON.stringify({ format: 1, id: 'test-player', sources, payloads,
    qualification: { physicalDevices: false, xcodeCompiled: false } }));
  return { root, write, payloads };
}

test('integrated player check accepts matching bytes, preserves qualification limits and isolates platforms', async () => {
  const f = await fixture();
  const result = await verifyUnityPlayers(f.root);
  assert.equal(result.verifiedFiles, 7);
  assert.equal(result.physicalDevicesQualified, false);
  assert.equal(result.xcodePreviouslyCompiled, false);
  await fs.unlink(path.join(f.root, Object.keys(f.payloads.ios)[0]));
  await verifyUnityPlayers(f.root, 'web');
  await assert.rejects(verifyUnityPlayers(f.root, 'ios'), /ENOENT/);
});

test('integrated player check rejects stale source, added source, changed binaries and LFS placeholders', async () => {
  for (const change of ['source', 'added-source', 'binary', 'lfs']) {
    const f = await fixture();
    if (change === 'source') await f.write('unity/Halabessa/Assets/sample.cs', 'changed');
    if (change === 'added-source') await f.write('unity/Halabessa/Assets/new.cs', 'new');
    if (change === 'binary') await f.write(Object.keys(f.payloads.android)[0], 'changed');
    if (change === 'lfs') await f.write(Object.keys(f.payloads.android)[0], 'version https://git-lfs.github.com/spec/v1\n');
    await assert.rejects(verifyUnityPlayers(f.root, 'android'), /changed|Stale|Git LFS/);
  }
});
