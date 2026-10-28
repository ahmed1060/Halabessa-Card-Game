import * as fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { brotliDecompressSync } from 'node:zlib';
import { digest } from './integrate_unity_release.mjs';
import { sourceDigests } from './prepare_unity_release.mjs';

export function verifyIosIntegration(podfile, scheme, project) {
  if (/target ['"]UnityFramework['"] do/.test(podfile) || /firebase-ios-sdk|FirebaseCpp|FirebaseAuth|FirebaseDatabase/.test(project)) {
    throw new Error('Stale Unity Firebase integration remains');
  }
  if (/--usymtool-path=|[A-Za-z]:[/\\]/.test(project)) throw new Error('Machine-specific Xcode project path');
  if (!/BlueprintName\s*=\s*"UnityFramework"[\s\S]*?ReferencedContainer\s*=\s*"container:UnityLibrary\/Unity-iPhone.xcodeproj"/.test(scheme)) {
    throw new Error('Runner scheme must explicitly build the embedded UnityFramework');
  }
  const entry = scheme.match(/<BuildableReference\b[^>]*BlueprintName\s*=\s*"UnityFramework"[^>]*>/)?.[0] ?? '';
  const guid = entry.match(/BlueprintIdentifier\s*=\s*"([A-F0-9]{24})"/)?.[1];
  if (!guid || !project.includes(`${guid} /* UnityFramework */ = {`) ||
      !new RegExp(`${guid} /\\* UnityFramework \\*/ = \\{\\s*isa = PBXNativeTarget;`).test(project)) {
    throw new Error('Runner scheme references a missing UnityFramework target');
  }
  const launch = scheme.match(/<LaunchAction\b[\s\S]*?<\/LaunchAction>/)?.[0] ?? '';
  if (!/BuildableName\s*=\s*"Runner.app"/.test(launch) || launch.includes('Unity-iPhone.app')) throw new Error('Runner must remain the app launcher');
  if (!project.includes('path = Data; sourceTree = "<group>";') || !project.includes('name = UnityFramework;')) {
    throw new Error('Missing relative Unity Data or framework target');
  }
}
export async function verifyUnityPlayers(root, platform = 'all') {
  const manifest = JSON.parse(await fs.readFile(path.join(root, 'unity/player-release.json')));
  if (manifest.format !== 1 || !/^[a-z0-9-]+$/.test(manifest.id) ||
      !['all', 'android', 'ios', 'web'].includes(platform)) throw new Error('Invalid Unity release manifest/platform');
  const currentSources = await sourceDigests(root);
  if (JSON.stringify(Object.keys(currentSources).sort()) !== JSON.stringify(Object.keys(manifest.sources).sort())) {
    throw new Error('Unity source file set changed; export new players');
  }
  const checked = new Set();
  async function check(name, expected) {
    if (name.includes('..') || path.isAbsolute(name) || name.includes('\\')) throw new Error('Invalid release file path');
    const bytes = await fs.readFile(path.join(root, name));
    if (bytes.subarray(0, 100).toString().startsWith('version https://git-lfs.github.com/spec/v1')) {
      throw new Error(`Fetch the actual Git LFS object: ${name}`);
    }
    if (digest(bytes, name) !== expected) throw new Error(`Stale/changed Unity release file: ${name}`);
    checked.add(name);
  }
  for (const [name, hash] of Object.entries(manifest.sources)) await check(name, hash);
  const platforms = platform === 'all' ? ['android', 'ios', 'web'] : [platform];
  const markers = ['REQUEST_READY', 'UNITY_VIEWPORT_CHANGED', 'UNITY_CARD_FEEL_READY', 'VISUAL_CONTACT', 'VISUAL_ACTION_COMPLETE'];
  for (const target of platforms) {
    const entries = Object.entries(manifest.payloads[target] ?? {});
    if (entries.length === 0) throw new Error(`No qualified ${target} payload`);
    for (const [name, hash] of entries) await check(name, hash);
    const metadata = target === 'android'
      ? 'androidBuild/unityExport/unityLibrary/src/main/assets/bin/Data/Managed/Metadata/global-metadata.dat'
      : target === 'ios' ? 'ios/UnityLibrary/Data/Managed/Metadata/global-metadata.dat' : 'web/Build/web.data.unityweb';
    let bytes = await fs.readFile(path.join(root, metadata));
    if (target === 'web') bytes = brotliDecompressSync(bytes);
    for (const marker of markers) if (!bytes.includes(Buffer.from(marker))) throw new Error(`Missing ${target} capability: ${marker}`);
  }
  if (platform === 'all' || platform === 'ios') {
    const read = name => fs.readFile(path.join(root, name), 'utf8');
    verifyIosIntegration(await read('ios/Podfile'),
      await read('ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme'),
      await read('ios/UnityLibrary/Unity-iPhone.xcodeproj/project.pbxproj'));
  }
  return { id: manifest.id, platforms, verifiedFiles: checked.size,
    physicalDevicesQualified: manifest.qualification.physicalDevices,
    xcodePreviouslyCompiled: manifest.qualification.xcodeCompiled };
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify(await verifyUnityPlayers(fileURLToPath(new URL('..', import.meta.url)), process.argv[2] ?? 'all'), null, 2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
