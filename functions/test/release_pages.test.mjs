import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, access } from 'node:fs/promises';
import { releasePage } from '../../scripts/generate-release-pages.mjs';
const root = new URL('../../', import.meta.url);

for (const kind of ['privacy', 'terms']) {
  test(`${kind} website matches the same English/Arabic source used in the app`, async () => {
    const html = await readFile(new URL(`web/${kind}.html`, root), 'utf8');
    assert.equal(html, await releasePage(kind));
    const copy = JSON.parse(await readFile(new URL(`assets/legal/${kind}.json`, root), 'utf8'));
    for (const language of ['en', 'ar']) {
      assert.ok(copy[language].sections.length >= 5);
      assert.ok(html.includes(copy[language].title));
      assert.ok(copy[language].sections.some(section => section.body.includes('weirdpuzz@gmail.com')));
    }
    assert.match(html, /lang="ar" dir="rtl"/);
    assert.doesNotMatch(html, /<script|<iframe|https?:\/\/.*\.js/i);
    for (const [, path] of html.matchAll(/href="\/([^"<>]+\.html)"/g)) await access(new URL(`web/${path}`, root));
  });
}
test('deletion page does not claim that a request means completed deletion', async () => {
  const html = await readFile(new URL('web/delete-account.html', root), 'utf8');
  assert.match(html, /Automatic in-app deletion is still being completed/);
  assert.match(html, /not confirmation that your account or data has been deleted/);
  assert.match(html, /Never send your password/);
  assert.match(html, /lang="ar" dir="rtl"/);
});
test('policy generator rejects arbitrary filesystem paths', async () => {
  await assert.rejects(releasePage('../secrets'), /invalid_policy/);
});
