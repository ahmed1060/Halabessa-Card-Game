{{flutter_js}}
{{flutter_build_config}}

// A mobile browser can pan its visual viewport after editing or rotation.
// Keep one real (untransformed) host at that origin; Flutter's custom-element
// ResizeObserver and hit testing then use the same CSS-pixel rectangle.
function configureGameViewport(host, browser = window) {
  let scheduled = false;
  function update() {
    scheduled = false;
    const viewport = browser.visualViewport;
    const width = viewport ? viewport.width : browser.innerWidth;
    const height = viewport ? viewport.height : browser.innerHeight;
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) return;
    const left = viewport
      ? (viewport.pageLeft ?? viewport.offsetLeft + (browser.scrollX || 0))
      : (browser.scrollX || 0);
    const top = viewport
      ? (viewport.pageTop ?? viewport.offsetTop + (browser.scrollY || 0))
      : (browser.scrollY || 0);
    const bounds = {
      left: `${Number.isFinite(left) ? left : 0}px`,
      top: `${Number.isFinite(top) ? top : 0}px`,
      width: `${width}px`,
      height: `${height}px`,
    };
    for (const [property, value] of Object.entries(bounds)) {
      if (host.style[property] !== value) host.style[property] = value;
    }
  }
  function schedule() {
    if (scheduled) return;
    scheduled = true;
    browser.requestAnimationFrame(update);
  }
  for (const event of ['load', 'resize', 'orientationchange', 'pageshow', 'scroll']) {
    browser.addEventListener(event, schedule, { passive: true });
  }
  if (browser.visualViewport) {
    browser.visualViewport.addEventListener('resize', schedule, { passive: true });
    browser.visualViewport.addEventListener('scroll', schedule, { passive: true });
  }
  update();
  // First-load browser chrome may settle after this script runs, without a
  // rotation. Measure again at the next paint and when the engine is mounted.
  schedule();
  return schedule;
}

// Retire only this app's legacy offline-first worker. Do not clear sign-in,
// preferences, other service workers, or browser storage.
async function startGame() {
  if ('serviceWorker' in navigator) {
    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      const workerUrl = new URL('flutter_service_worker.js', document.baseURI);
      await Promise.all(registrations.filter(registration => {
        const worker = registration.active || registration.waiting || registration.installing;
        if (!worker) return false;
        const url = new URL(worker.scriptURL);
        return url.origin === workerUrl.origin && url.pathname === workerUrl.pathname;
      }).map(registration => registration.unregister()));
    } catch (error) {
      console.warn('Could not retire legacy Flutter cache', error);
    }
  }
  const host = document.getElementById('game-host');
  if (!host) throw new Error('Game viewport host is missing');
  const refreshViewport = configureGameViewport(host);
  await _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      const engine = await engineInitializer.initializeEngine({ hostElement: host });
      refreshViewport();
      await engine.runApp();
      refreshViewport();
    },
  });
}
startGame();
