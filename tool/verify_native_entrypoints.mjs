import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

/** Text XML after Android's manifest merger, not a binary APK manifest. */
export function launcherActivities(xml) {
  return [...xml.matchAll(/<(activity|activity-alias)\b([^>]*)(?:\/\s*>|>([\s\S]*?)<\/\1>)/g)]
    .filter(([, , , body = '']) => [...body.matchAll(/<intent-filter\b[^>]*>([\s\S]*?)<\/intent-filter>/g)]
      .some(([, filter]) => /android\.intent\.action\.MAIN/.test(filter) &&
        /android\.intent\.category\.LAUNCHER/.test(filter)))
    .map(([, , attributes]) => attributes.match(/android:name="([^"]+)"/)?.[1]);
}

export function verifyMergedAndroidManifest(xml) {
  const launchers = launcherActivities(xml);
  if (launchers.length !== 1 || !/^(?:\.|com\.halabessa\.game\.)MainActivity$/.test(launchers[0] ?? '')) {
    throw new Error(`Expected only Flutter MainActivity as launcher; found ${JSON.stringify(launchers)}`);
  }
  return launchers;
}

export async function verifyNativeEntrypointSources(root) {
  const read = (path) => readFile(resolve(root, path), 'utf8');
  const app = await read('android/app/src/main/AndroidManifest.xml');
  verifyMergedAndroidManifest(app);
  if (!/<activity\s+android:name="com\.unity3d\.player\.UnityPlayerActivity"\s*>\s*<intent-filter\s+tools:node="removeAll"\s*\/>\s*<\/activity>/.test(app)) {
    throw new Error('The app must remove exported Unity launcher filters without deleting the activity');
  }
  const scheme = await read('ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme');
  const launch = scheme.match(/<LaunchAction\b[\s\S]*?<\/LaunchAction>/)?.[0] ?? '';
  if (!/BuildableName\s*=\s*"Runner\.app"/.test(launch) || /BuildableName\s*=\s*"Unity-iPhone\.app"/.test(launch)) {
    throw new Error('The iOS launch scheme must run Runner, not standalone Unity');
  }
  const project = await read('ios/Runner.xcodeproj/project.pbxproj');
  if (!/UnityFramework\.framework in Embed Frameworks/.test(project)) {
    throw new Error('Runner must retain its embedded Unity framework');
  }
  return 'Source contracts passed; a merged APK and real-device launch still require qualification.';
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = fileURLToPath(new URL('../', import.meta.url));
  console.log(await verifyNativeEntrypointSources(root));
  if (process.argv[2]) {
    console.log('Merged Android launchers:', verifyMergedAndroidManifest(await readFile(process.argv[2], 'utf8')));
  }
}
