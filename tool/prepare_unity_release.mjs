// Local staging only. Does not replace shipping players or invoke a publisher.
import { constants } from 'node:fs';
import * as fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { brotliDecompressSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';

const markers = ['REQUEST_READY', 'UNITY_VIEWPORT_CHANGED',
  'UNITY_CARD_FEEL_READY', 'VISUAL_CONTACT', 'VISUAL_ACTION_COMPLETE'];
const metadata = {
  android: 'android/unityLibrary/src/main/assets/bin/Data/Managed/Metadata/global-metadata.dat',
  ios: 'ios/Data/Managed/Metadata/global-metadata.dat',
};
const webNames = ['web.data.unityweb', 'web.framework.js.unityweb',
  'web.loader.js', 'web.wasm.unityweb'];
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const json = async file => JSON.parse(await fs.readFile(file, 'utf8'));
function beneath(root, target) {
  const relative = path.relative(root, target);
  if (!relative || relative.startsWith(`..${path.sep}`) || relative === '..' ||
      path.isAbsolute(relative)) throw new Error('Expected a new path inside build/');
}
async function files(root, relative = '', excluded = new Set()) {
  const result = [];
  for (const entry of await fs.readdir(path.join(root, relative), { withFileTypes: true })) {
    const name = path.posix.join(relative, entry.name);
    if (excluded.has(name)) continue;
    if (entry.isSymbolicLink()) throw new Error(`Symlink is not a portable payload: ${name}`);
    if (entry.isDirectory()) result.push(...await files(root, name, excluded));
    else if (entry.isFile()) result.push(name);
  }
  return result.sort();
}
async function digests(root, names) {
  const result = {};
  for (const name of names) {
    const bytes = await fs.readFile(path.join(root, name));
    if (bytes.subarray(0, 100).toString().startsWith('version https://git-lfs.github.com/spec/v1')) {
      throw new Error(`Unresolved Git LFS pointer: ${name}`);
    }
    result[name] = { bytes: bytes.length, sha256: hash(bytes) };
  }
  return result;
}
export async function sourceDigests(checkout) {
  const names = [];
  for (const tree of ['Assets', 'ProjectSettings', 'Packages']) {
    for (const name of await files(path.join(checkout, 'unity/Halabessa', tree))) {
      names.push(`unity/Halabessa/${tree}/${name}`);
    }
  }
  // Normalize text line endings in source manifests across Windows/macOS/CI.
  const result = {};
  for (const name of names.sort()) {
    let bytes = await fs.readFile(path.join(checkout, name));
    if (/\.(cs|meta|asset|unity|prefab|json|xml|gradle|properties|txt|shader|hlsl|asmdef)$/.test(name)) {
      bytes = Buffer.from(bytes.toString('utf8').replaceAll('\r\n', '\n'));
    }
    result[name] = hash(bytes);
  }
  return result;
}
async function validatePlayers(root) {
  for (const name of Object.values(metadata)) {
    const text = (await fs.readFile(path.join(root, name))).toString('latin1');
    for (const marker of markers) if (!text.includes(marker)) {
      throw new Error(`Stale Unity player (${marker} missing): ${name}`);
    }
  }
  for (const name of ['libil2cpp.so', 'libunity.so', 'libmain.so']) {
    const bytes = await fs.readFile(path.join(root,
      'android/unityLibrary/src/main/jniLibs/arm64-v8a', name));
    if (bytes.length < 64 || bytes.subarray(0, 6).toString('hex') !== '7f454c460201' ||
        bytes.readUInt16LE(18) !== 183) throw new Error(`Expected ARM64 ELF: ${name}`);
  }
  const wasm = brotliDecompressSync(await fs.readFile(path.join(root, 'web/Build/web.wasm.unityweb')));
  if (wasm.subarray(0, 8).toString('hex') !== '0061736d01000000') {
    throw new Error('Expected a Brotli Unity WebAssembly player');
  }
  const data = brotliDecompressSync(await fs.readFile(path.join(root, 'web/Build/web.data.unityweb')));
  for (const marker of markers) if (!data.includes(Buffer.from(marker))) {
    throw new Error(`Stale WebGL player: ${marker}`);
  }
  const archive = await fs.readFile(path.join(root, 'ios/Libraries/libiPhone-lib.a'));
  if (archive.subarray(0, 8).toString() !== '!<arch>\n') {
    throw new Error('Expected the iOS Unity static archive');
  }
}

export async function prepare(checkoutPath, exportPath, outputPath) {
  const checkout = await fs.realpath(checkoutPath);
  const build = await fs.realpath(path.join(checkout, 'build'));
  const input = await fs.realpath(exportPath);
  const output = path.resolve(outputPath);
  beneath(build, input);
  beneath(build, output);
  const parent = await fs.realpath(path.dirname(output));
  if (parent !== build) beneath(build, parent);
  if (output === input || output.startsWith(input + path.sep) || input.startsWith(output + path.sep)) {
    throw new Error('Export and staged output must be separate');
  }
  const reports = {};
  for (const [folder, target] of [['android', 'Android'], ['ios', 'iOS'], ['web', 'WebGL']]) {
    const report = await json(path.join(input, `${folder}-export.json`));
    if (report.target !== target || report.result !== 'Succeeded' || report.errors !== 0 ||
        await fs.realpath(report.output) !== await fs.realpath(path.join(input, folder))) {
      throw new Error(`Unqualified ${target} export report`);
    }
    reports[folder] = { target, result: report.result, errors: report.errors, warnings: report.warnings };
  }
  await validatePlayers(input);
  const source = await sourceDigests(checkout);
  // mkdir without recursive/exist_ok prevents overwriting prior evidence.
  await fs.mkdir(output);
  const copy = async (from, to) => {
    const info = await fs.lstat(from);
    if (info.isSymbolicLink()) throw new Error('Symlink input rejected');
    const names = info.isDirectory() ? await files(from) : [''];
    for (const name of names) {
      const dest = path.join(to, name);
      await fs.mkdir(path.dirname(dest), { recursive: true });
      await fs.copyFile(path.join(from, name), dest, constants.COPYFILE_EXCL);
    }
  };
  // Precompiled Android payload; do not copy Windows IL2CPP executables, caches,
  // symbols, Firebase remnants or the generated machine-specific Gradle file.
  for (const name of ['assets', 'cpp', 'java', 'jniLibs', 'res', 'resources', 'AndroidManifest.xml']) {
    await copy(path.join(input, 'android/unityLibrary/src/main', name),
      path.join(output, 'android/unityLibrary/src/main', name));
  }
  for (const name of ['libs', 'proguard-unity.txt']) {
    await copy(path.join(input, 'android/unityLibrary', name),
      path.join(output, 'android/unityLibrary', name));
  }
  for (const name of ['unityLibrary/build.gradle', 'shared/keepUnitySymbols.gradle']) {
    await copy(path.join(checkout, 'androidBuild/unityExport', name), path.join(output, 'android', name));
  }
  await copy(path.join(input, 'ios'), path.join(output, 'ios'));
  for (const name of webNames) await copy(path.join(input, 'web/Build', name), path.join(output, 'web/Build', name));
  const payload = await digests(output, await files(output));
  const iosProject = await fs.readFile(path.join(output, 'ios/Unity-iPhone.xcodeproj/project.pbxproj'), 'utf8');
  const portability = {
    iosWindowsSymbolToolArgument: /--usymtool-path=.*[A-Za-z]:\//.test(iosProject),
  };
  const shipping = {};
  for (const [target, rel] of Object.entries(metadata)) {
    const name = target === 'android' ? rel.replace('android/', 'androidBuild/unityExport/') : rel.replace('ios/', 'ios/UnityLibrary/');
    const bytes = await fs.readFile(path.join(checkout, name));
    shipping[target] = { path: name, sha256: hash(bytes), matchesStaged: hash(bytes) === payload[rel].sha256 };
  }
  for (const name of webNames) {
    const rel = `web/Build/${name}`;
    const bytes = await fs.readFile(path.join(checkout, rel));
    shipping[name] = { path: rel, sha256: hash(bytes), matchesStaged: hash(bytes) === payload[rel].sha256 };
  }
  const manifest = { format: 1, releaseReady: false, reports, source, portability,
    sourceBinding: 'Source observed at staging; export reports do not attest a source hash. Rebuild if source provenance is uncertain.',
    payload, shipping, gates: [
      'Existing shipping paths were not changed. Review integration before copying staged players.',
      'Android uses precompiled ARM64 libraries and existing portable Gradle integration; unityRebuildIl2Cpp is not supported by this payload.',
      'Fresh iOS export has no Unity Firebase dependency. Review Runner/Podfile/project integration and compile on macOS before promotion.',
      ...(portability.iosWindowsSymbolToolArgument ? ['Generated Xcode project contains the Windows exporter symbol-tool argument. Resolve/qualify it on macOS before promotion.'] : []),
      'Physical Android/iPhone Wi-Fi, permissions, Unity compositing, gestures, audio and haptics remain unqualified.',
    ] };
  await fs.writeFile(path.join(output, 'unity-release-manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, { flag: 'wx' });
  await verify(checkout, output);
  return { files: Object.keys(payload).length, bytes: Object.values(payload).reduce((n, f) => n + f.bytes, 0),
    sourceFiles: Object.keys(source).length, releaseReady: false, portability,
    shippingMatches: Object.fromEntries(Object.entries(shipping).map(([k, v]) => [k, v.matchesStaged])) };
}

export async function verify(checkout, output) {
  const manifest = await json(path.join(output, 'unity-release-manifest.json'));
  if (manifest.format !== 1 || manifest.releaseReady !== false) throw new Error('Invalid review manifest');
  if (JSON.stringify(await sourceDigests(checkout)) !== JSON.stringify(manifest.source)) {
    throw new Error('Unity source changed since staging; rebuild/review the players');
  }
  // AGP creates CMake's local working cache beside this precompiled module.
  // It is never a release payload and must not enter the manifest or a commit.
  const names = (await files(output, '', new Set(['android/unityLibrary/.cxx'])))
    .filter(n => n !== 'unity-release-manifest.json');
  if (JSON.stringify(await digests(output, names)) !== JSON.stringify(manifest.payload)) {
    throw new Error('Staged player payload changed');
  }
  await validatePlayers(output);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [mode, input, output] = process.argv.slice(2);
    const checkout = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
    if (mode === 'prepare' && input && output) console.log(JSON.stringify(await prepare(checkout, input, output), null, 2));
    else if (mode === 'verify' && input && !output) {
      await verify(checkout, input);
      console.log('Unity staging source/payload verification passed; release gates remain open.');
    } else throw new Error('Usage: node tool/prepare_unity_release.mjs prepare <export-root> <new-build-output> | verify <staged-output>');
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
