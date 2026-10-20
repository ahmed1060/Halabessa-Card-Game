# Halabessa search visibility

## Scope

The user approved a bilingual public landing page and then explicitly authorized
publishing the SEO changes. The preferred public address is
`https://halabessa-card-game1.web.app/`, matching the Firebase project and its
verified HTTP 200 HTTPS response. A custom domain was not purchased or assumed.

The homepage contains readable HTML for Halabessa Card Game, لعبة حلبسة, and the
alternate Arabic spelling حلبسه. It serves the same content to people and bots;
there is no user-agent detection, invisible keyword block, fabricated rating,
or promise of a particular search position.

## Files and behavior

- `web/landing.html`, `landing.css`, and `landing-route.js`: public bilingual
  content, ordinary Play links, semantic sections, canonical URL, social preview
  metadata, and WebSite structured data. The screenshot is a test-fixture render
  of the real game interface, not private player content or a live player count.
- `web/robots.txt` and `sitemap.xml`: discoverable canonical public URLs.
  Game/account/hash URLs are not advertised as search results.
- `scripts/version-web-build.mjs`: retains the existing matching fingerprinted
  Flutter code/bootstrap, saves the playable shell to `play.html`, then publishes
  the public HTML as `index.html`. Builds without the landing file retain the
  prior behavior. The existing main CI already invokes this packaging step.
- `web/index.html`: remains Flutter's build input, but its interactive output is
  noindex. It does not replace the indexable public homepage after packaging.
- `web/manifest.json`: installed web apps open the game directly. Explicit ID
  `/` preserves the previous root-based identity while the start URL changes.
- `firebase.json`: unknown application paths retain the playable-shell fallback;
  actual static public files are served directly.
- Old links such as `/#/game` and `/#/account/delete` forward to `play.html` with
  their original query/hash. Homepage section anchors stay on the homepage.
- `functions/test/search_landing.test.mjs` is added to the existing pre-deploy
  test step. No Flutter game, state, rules, authority, Unity or account data changes.

The web and frontend-design skills guided semantic navigation, readable RTL/LTR
content, fixed image dimensions, hero loading priority, and reuse of the approved
game artwork/palette. No new runtime package or analytics was added.

## Verification

29 focused web tests passed: metadata, discovery files, legacy link forwarding,
matching fingerprinted game entrypoints, viewport, startup, and legal pages.
The existing Unity host test also passed. Local isolated preview is at
`http://127.0.0.1:9112/`; its Play link uses the offline design-review entrypoint.
Production CI still builds `lib/main.dart`, not the local preview entrypoint.

## Google owner setup after deployment

1. Open `https://search.google.com/search-console` using the Google account that
   should own the site. Do not share passwords, recovery codes or access tokens.
2. Check existing properties first. If absent, add a **URL-prefix** property:
   `https://halabessa-card-game1.web.app/`. The Firebase-provided web.app domain
   is not a DNS zone owned by this project, so do not claim the whole web.app domain.
3. Use an available ownership-verification method. If Google provides an HTML
   verification tag/file, copy that public tag/file for a scoped deployment;
   never insert a made-up verification code. Confirm the intended owner account
   before granting it Search Console ownership.
4. In Sitemaps, submit `https://halabessa-card-game1.web.app/sitemap.xml`.
5. Inspect `https://halabessa-card-game1.web.app/`, test the live URL, and request
   indexing when allowed. Review the Pages/Indexing and Performance reports.

Publication and a successful crawl do not guarantee indexing, first place, or
visibility for every spelling. Search Console is the source for actual Google
index status; a third-party search query is not proof of inclusion/exclusion.

References:
- https://docs.flutter.dev/platform-integration/web/faq
- https://developers.google.com/search/docs/fundamentals/get-started-developers
- https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap
- https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl
