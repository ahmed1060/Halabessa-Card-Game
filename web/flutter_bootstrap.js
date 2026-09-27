{{flutter_js}}
{{flutter_build_config}}

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
  await _flutter.loader.load();
}
startGame();
