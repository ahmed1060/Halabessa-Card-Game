import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { fingerprintWebArtwork } from './fingerprint-web-artwork.mjs';

const digest = content => createHash('sha256').update(content).digest('hex').slice(0, 16);

export async function versionWebBuild(directory) {
  const main = await readFile(resolve(directory, 'main.dart.js'));
  const originalBootstrap = await readFile(resolve(directory, 'flutter_bootstrap.js'), 'utf8');
  const originalIndex = await readFile(resolve(directory, 'index.html'), 'utf8');
  if (!originalBootstrap.includes('"mainJsPath":"main.dart.js"') ||
      !originalIndex.includes('src="flutter_bootstrap.js"')) {
    throw new Error('Unexpected Flutter entrypoint format; refusing an unversioned deployment');
  }
  const mainName = `main.${digest(main)}.dart.js`;
  const bootstrap = originalBootstrap.replace('"mainJsPath":"main.dart.js"', `"mainJsPath":"${mainName}"`);
  const bootstrapName = `flutter_bootstrap.${digest(bootstrap)}.js`;
  const index = originalIndex.replace('src="flutter_bootstrap.js"', `src="${bootstrapName}"`);
  const artworkCount = await fingerprintWebArtwork(directory);
  // Keep original files for already-open clients. New pages use fingerprinted
  // paths that cannot resolve to an older HTTP/service-worker cached bundle.
  await writeFile(resolve(directory, mainName), main);
  await writeFile(resolve(directory, bootstrapName), bootstrap);
  await writeFile(resolve(directory, 'index.html'), index);
  return { mainName, bootstrapName, artworkCount };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  console.log(await versionWebBuild(resolve(process.argv[2] || 'build/web')));
}
