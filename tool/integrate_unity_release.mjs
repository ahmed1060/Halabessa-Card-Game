// Reversible local packaging integration. Never invokes Git or a publisher.
import * as fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { verify } from './prepare_unity_release.mjs';

export const textPayload = /\.(cs|meta|asset|unity|prefab|json|xml|gradle|properties|txt|shader|hlsl|asmdef|h|c|cpp|m|mm|pbxproj|xcscheme|js|sh|plist|storyboard)$/;
export function digest(bytes, name) {
  if (textPayload.test(name)) bytes = Buffer.from(bytes.toString('utf8').replaceAll('\r\n', '\n'));
  return createHash('sha256').update(bytes).digest('hex');
}
export function normalizeIosProject(text) {
  // An iOS export made on Windows leaves an unused Windows-only symbol tool
  // argument in its Mac IL2CPP phase. Symbol generation needs an actual Mac
  // tool, so reject that configuration rather than silently removing it.
  if (text.includes('--generate-usym-file')) throw new Error('Symbol generation requires a qualified Mac tool');
  const option = / --usymtool-path=\\"[A-Za-z]:[^\r\n]*?\\"/g;
  const matches = [...text.matchAll(option)];
  if (matches.length !== 1) throw new Error('Expected exactly one Windows exporter symbol-tool argument');
  const result = text.replace(option, '');
  if (/--usymtool-path=|[A-Za-z]:[/\\]/.test(result)) throw new Error('Unresolved machine-specific Xcode project path');
  if (!/path = Data; sourceTree = "<group>";/.test(result) || !result.includes('name = UnityFramework;')) {
    throw new Error('Expected relative Data and the embedded UnityFramework target');
  }
  return result;
}
function inside(root, target) {
  const rel = path.relative(root, target);
  if (!rel || rel === '..' || rel.startsWith(`..${path.sep}`) || path.isAbsolute(rel)) {
    throw new Error('Refusing filesystem operation outside the named checkout');
  }
}
export function shippingPath(name) {
  if (name.startsWith('android/')) return `androidBuild/unityExport/${name.slice(8)}`;
  if (name.startsWith('ios/')) return `ios/UnityLibrary/${name.slice(4)}`;
  if (name.startsWith('web/Build/')) return name;
  throw new Error(`Unexpected staged payload path: ${name}`);
}
export async function integrate(checkoutPath, candidatePath, archivePath) {
  const root = await fs.realpath(checkoutPath);
  const build = await fs.realpath(path.join(root, 'build'));
  const candidate = await fs.realpath(candidatePath);
  const archive = path.resolve(archivePath);
  inside(build, candidate);
  inside(build, archive);
  if (await fs.realpath(path.dirname(archive)) !== build) throw new Error('Archive must be directly inside build/');
  await verify(root, candidate);
  const staged = JSON.parse(await fs.readFile(path.join(candidate, 'unity-release-manifest.json')));
  try {
    await fs.access(path.join(root, 'unity/player-release.json'));
    throw new Error('An integrated player manifest already exists; review it before integrating again');
  } catch (error) { if (error.code !== 'ENOENT') throw error; }
  for (const old of Object.values(staged.shipping)) {
    const current = createHash('sha256').update(await fs.readFile(path.join(root, old.path))).digest('hex');
    if (current !== old.sha256) throw new Error(`Shipping player changed after staging: ${old.path}`);
  }
  // Preflight the only generated-code transformation before moving anything.
  const iosName = 'Unity-iPhone.xcodeproj/project.pbxproj';
  const iosProject = normalizeIosProject(await fs.readFile(path.join(candidate, 'ios', iosName), 'utf8'));
  const mappings = [
    ['androidBuild/unityExport/unityLibrary', 'android/unityLibrary'],
    ['ios/UnityLibrary', 'ios'], ['web/Build', 'web/Build'],
  ];
  for (const [shipping] of mappings) {
    const target = path.resolve(root, shipping);
    inside(root, target);
    if (await fs.realpath(target) !== target || (await fs.lstat(target)).isSymbolicLink()) {
      throw new Error(`Expected an ordinary export directory: ${shipping}`);
    }
  }
  await fs.mkdir(archive); // Never overwrite earlier recovery evidence.
  for (const name of ['web/unity-release.json', 'web/index.html', 'ios/Podfile',
    'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme']) {
    const dest = path.join(archive, 'integration-files', name);
    await fs.mkdir(path.dirname(dest), { recursive: true });
    await fs.copyFile(path.join(root, name), dest, fs.constants.COPYFILE_EXCL);
  }
  const journal = { format: 1, localOnly: true, mappings, completed: [] };
  const journalFile = path.join(archive, 'recovery.json');
  await fs.writeFile(journalFile, JSON.stringify(journal, null, 2));
  for (const [shipping, from] of mappings) {
    const target = path.resolve(root, shipping);
    const backup = path.resolve(archive, shipping);
    // Verify final absolute paths immediately before each directory move.
    inside(root, target);
    inside(archive, backup);
    await fs.mkdir(path.dirname(backup), { recursive: true });
    await fs.rename(target, backup);
    journal.completed.push({ shipping, originalArchived: true, copied: false });
    await fs.writeFile(journalFile, JSON.stringify(journal, null, 2));
    await fs.cp(path.join(candidate, from), target, { recursive: true, force: false, errorOnExist: true });
    journal.completed.at(-1).copied = true;
    await fs.writeFile(journalFile, JSON.stringify(journal, null, 2));
  }
  await fs.writeFile(path.join(root, 'ios/UnityLibrary', iosName), iosProject);
  const payloads = { android: {}, ios: {}, web: {} };
  for (const name of Object.keys(staged.payload).sort()) {
    const platform = name.split('/')[0];
    const shipping = shippingPath(name);
    payloads[platform][shipping] = digest(await fs.readFile(path.join(root, shipping)), shipping);
  }
  const id = `lan-unity-20261028-${createHash('sha256').update(JSON.stringify(payloads)).digest('hex').slice(0, 12)}`;
  const sources = {};
  for (const name of Object.keys(staged.source)) sources[name] = digest(await fs.readFile(path.join(root, name)), name);
  const manifest = { format: 1, id, review: 'docs/unity-export-integration-review-2026-10-28.md',
    qualification: { physicalDevices: false, xcodeCompiled: false },
    sourceBinding: staged.sourceBinding, sources, payloads };
  await fs.writeFile(path.join(root, 'unity/player-release.json'), `${JSON.stringify(manifest, null, 2)}\n`, { flag: 'wx' });
  const oldWeb = JSON.parse(await fs.readFile(path.join(root, 'web/unity-release.json')));
  const web = { id, sourceReview: manifest.review, files: {}, sources: {} };
  for (const name of Object.keys(oldWeb.files)) {
    web.files[name] = createHash('sha256').update(await fs.readFile(path.join(root, 'web', name))).digest('hex');
  }
  for (const name of Object.keys(oldWeb.sources)) web.sources[name] = staged.source[name];
  const html = await fs.readFile(path.join(root, 'web/index.html'), 'utf8');
  const references = html.split(oldWeb.id).length - 1;
  if (references !== 2) throw new Error(`Expected two stable loader identifiers, got ${references}; originals are archived`);
  await fs.writeFile(path.join(root, 'web/index.html'), html.replaceAll(oldWeb.id, id));
  await fs.writeFile(path.join(root, 'web/unity-release.json'), `${JSON.stringify(web, null, 2)}\n`);
  journal.finished = true;
  await fs.writeFile(journalFile, JSON.stringify(journal, null, 2));
  return { id, payloadFiles: Object.values(payloads).reduce((n, p) => n + Object.keys(p).length, 0),
    recovery: path.relative(root, archive).replaceAll('\\', '/'), localOnly: true };
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [flag, candidate, archive] = process.argv.slice(2);
    if (flag !== '--apply-local' || !candidate || !archive) throw new Error('Usage: --apply-local <verified-candidate> <new-build-archive>');
    console.log(JSON.stringify(await integrate(fileURLToPath(new URL('..', import.meta.url)), candidate, archive), null, 2));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
