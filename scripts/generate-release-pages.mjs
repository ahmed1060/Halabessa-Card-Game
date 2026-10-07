import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
export async function releasePage(kind) {
  if (!['privacy', 'terms'].includes(kind)) throw new Error('invalid_policy');
  const text = JSON.parse(await readFile(resolve(root, `assets/legal/${kind}.json`), 'utf8'));
  const article = language => `<article id="${language}" lang="${language}" dir="${language === 'ar' ? 'rtl' : 'ltr'}"><h1>${escape(text[language].title)}</h1><p>${escape(text[language].updated)}</p>${text[language].sections.map(section => `<section><h2>${escape(section.title)}</h2><p>${escape(section.body)}</p></section>`).join('\n')}</article>`;
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(text.en.title)} — WeirdPuzz</title><link rel="stylesheet" href="/release-pages.css"></head>
<body><a class="skip" href="#en">Skip to content</a><main><nav aria-label="Page navigation"><a href="/">حلبسه / Halabessa</a><a href="#ar" lang="ar">العربية</a><a href="/support.html">Support</a><a href="/privacy.html">Privacy</a><a href="/terms.html">Rules of use</a><a href="/delete-account.html">Account deletion</a></nav>${article('en')}${article('ar')}<footer><a href="mailto:weirdpuzz@gmail.com">WeirdPuzz — weirdpuzz@gmail.com</a></footer></main></body></html>
`;
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  for (const kind of ['privacy', 'terms']) await writeFile(resolve(root, `web/${kind}.html`), await releasePage(kind));
}
