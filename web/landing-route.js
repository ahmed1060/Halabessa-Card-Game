// Existing Flutter hash links must continue to open their original destination.
// Normal visitors and crawlers get the same static homepage; no UA detection.
if (window.location.hash.startsWith('#/')) {
  const game = new URL('play.html', window.location.href);
  game.search = window.location.search;
  game.hash = window.location.hash;
  window.location.replace(game.href);
}
