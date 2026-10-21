import test from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { verifyMergedAndroidManifest, verifyNativeEntrypointSources } from '../../tool/verify_native_entrypoints.mjs';

const launcher = '<intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter>';
test('native entrypoint source contracts preserve Flutter launch and embedded Unity', async () => {
  await verifyNativeEntrypointSources(fileURLToPath(new URL('../../', import.meta.url)));
});
test('merged manifest accepts only Flutter launcher, not an embedded standalone Unity launcher', () => {
  const flutter = `<activity android:name="com.halabessa.game.MainActivity">${launcher}</activity>`;
  assert.deepEqual(verifyMergedAndroidManifest(flutter), ['com.halabessa.game.MainActivity']);
  assert.throws(() => verifyMergedAndroidManifest(`${flutter}<activity android:name="com.unity3d.player.UnityPlayerActivity">${launcher}</activity>`), /Expected only Flutter/);
  assert.throws(() => verifyMergedAndroidManifest(`${flutter}<activity-alias android:name="ExtraUnityIcon">${launcher}</activity-alias>`), /Expected only Flutter/);
  assert.throws(() => verifyMergedAndroidManifest('<application/>'), /Expected only Flutter/);
});
