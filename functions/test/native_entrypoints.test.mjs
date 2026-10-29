import test from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';
import { verifyMergedAndroidManifest, verifyNativeEntrypointSources } from '../../tool/verify_native_entrypoints.mjs';

const launcher = '<intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter>';
test('native entrypoint source contracts preserve Flutter launch and embedded Unity', async () => {
  await verifyNativeEntrypointSources(fileURLToPath(new URL('../../', import.meta.url)));
});

test('Android app packages the same supported ABI as its embedded Unity renderer', () => {
  const root = new URL('../../', import.meta.url);
  const app = readFileSync(new URL('android/app/build.gradle', root), 'utf8');
  const properties = readFileSync(new URL('android/gradle.properties', root), 'utf8');
  assert.match(app, /finalizeDsl[\s\S]*?defaultConfig\.ndk\.abiFilters\.clear\(\)[\s\S]*?defaultConfig\.ndk\.abiFilters\.add\('arm64-v8a'\)/);
  assert.match(properties, /^unity\.abiFilters=arm64-v8a\s*$/m);
});
test('merged manifest accepts only Flutter launcher, not an embedded standalone Unity launcher', () => {
  const flutter = `<activity android:name="com.halabessa.game.MainActivity">${launcher}</activity>`;
  assert.deepEqual(verifyMergedAndroidManifest(flutter), ['com.halabessa.game.MainActivity']);
  assert.throws(() => verifyMergedAndroidManifest(`${flutter}<activity android:name="com.unity3d.player.UnityPlayerActivity">${launcher}</activity>`), /Expected only Flutter/);
  assert.throws(() => verifyMergedAndroidManifest(`${flutter}<activity-alias android:name="ExtraUnityIcon">${launcher}</activity-alias>`), /Expected only Flutter/);
  assert.throws(() => verifyMergedAndroidManifest('<application/>'), /Expected only Flutter/);
});
