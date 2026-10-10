// QA-only revision tracker: no credentials, card values or snapshots are logged.
export class RevisionTracker {
  constructor(uid, roomId) {
    this.uid = uid; this.roomId = roomId; this.version = -1;
    this.waiters = new Set(); this.failure = null;
  }
  observe(view, now = performance.now()) {
    if (!view || !Number.isSafeInteger(view.version)) return;
    if (view.recipientUid !== this.uid || view.state?.id !== this.roomId ||
        'handCards' in view.state) throw Error('invalid_private_view');
    if (view.version < this.version) throw Error('revision_regressed');
    this.version = view.version;
    for (const waiter of [...this.waiters]) if (view.version >= waiter.version) {
      clearTimeout(waiter.timer); this.waiters.delete(waiter);
      waiter.resolve({version: view.version, ms: Math.round(now - waiter.started)});
    }
  }
  wait(version, started = performance.now(), timeout = 20000) {
    if (this.failure) return Promise.reject(this.failure);
    if (this.version >= version) return Promise.resolve({version: this.version, ms: 0});
    return new Promise((resolve, reject) => {
      const waiter = {version, started, resolve, reject};
      waiter.timer = setTimeout(() => {
        this.waiters.delete(waiter); reject(Error('revision_delivery_timeout'));
      }, timeout);
      this.waiters.add(waiter);
    });
  }
  fail(error = Error('feed_closed')) {
    this.failure = error;
    for (const waiter of this.waiters) { clearTimeout(waiter.timer); waiter.reject(error); }
    this.waiters.clear();
  }
}

export async function openRevisionFeed(url, uid, roomId) {
  const abort = new AbortController();
  const opening = setTimeout(() => abort.abort(), 20000);
  let response;
  try { response = await fetch(url, {headers: {Accept: 'text/event-stream'}, signal: abort.signal}); }
  finally { clearTimeout(opening); }
  if (response.status !== 200) { abort.abort(); throw Error('private_feed_denied'); }
  const tracker = new RevisionTracker(uid, roomId), reader = response.body.getReader();
  const consume = (async () => {
    let buffer = ''; const decoder = new TextDecoder();
    while (true) {
      const {value, done} = await reader.read(); if (done) throw Error('feed_closed');
      buffer += decoder.decode(value, {stream: true}); buffer = buffer.replaceAll('\r\n', '\n');
      let end;
      while ((end = buffer.indexOf('\n\n')) >= 0) {
        const frame = buffer.slice(0, end); buffer = buffer.slice(end + 2);
        const event = /^event: (.+)$/m.exec(frame)?.[1], data = /^data: (.+)$/m.exec(frame)?.[1];
        if (event === 'cancel' || event === 'auth_revoked') throw Error('feed_permission_revoked');
        if (event !== 'put' || !data) continue;
        const packet = JSON.parse(data);
        // Production publication writes a complete, atomic own view at root.
        if (packet.path === '/') tracker.observe(packet.data);
      }
    }
  })().catch(() => tracker.fail(Error('private_feed_failed')));
  return {tracker, close: async () => {
    tracker.fail(); abort.abort(); await reader.cancel().catch(() => {}); await consume;
  }};
}
