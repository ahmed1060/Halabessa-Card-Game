const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = fs.readFileSync(path.join(__dirname, '../../web/index.html'), 'utf8');
const bridge = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
const tick = () => new Promise(resolve => setImmediate(resolve));
function setup(start) {
  const messages = [];
  const listeners = {};
  const canvas = {
    style: {}, removeAttribute() {},
    addEventListener(name, fn) { listeners[name] = fn; },
  };
  const window = {
    location: { origin: 'https://game.example' },
    addEventListener() {},
    postMessage(message, origin) { messages.push({ event: JSON.parse(message).event, origin }); },
  };
  const context = vm.createContext({ window, console: { log() {}, error() {} }, createUnityInstance: start });
  vm.runInContext(bridge, context);
  return { window, canvas, messages, listeners, context };
}

test('initialization is lazy and duplicate starts cannot create extra engines', async () => {
  let starts = 0;
  let resolve;
  const promise = new Promise(r => { resolve = r; });
  const { window, canvas } = setup(() => { starts++; return promise; });
  assert.equal(starts, 0);
  window.initUnityEngine(canvas);
  window.initUnityEngine(canvas);
  await tick();
  assert.equal(starts, 1);
  assert.equal(canvas.style.visibility, 'hidden');
  resolve({ Module: {}, SendMessage() {} });
  await tick();
  assert.equal(canvas.style.visibility, 'visible');
  window.initUnityEngine(canvas);
  await tick();
  assert.equal(starts, 1);
});

test('synchronous and asynchronous loader failures notify Flutter and hide the canvas', async () => {
  for (const start of [() => { throw Error('GLctx'); }, () => Promise.reject(Error('GLctx'))]) {
    const { window, canvas, messages, context } = setup(start);
    window.initUnityEngine(canvas);
    await tick();
    assert.equal(context.unityStartupState, 'failed');
    assert.equal(canvas.style.visibility, 'hidden');
    assert.equal(canvas.style.pointerEvents, 'none');
    assert.deepEqual(messages, [{ event: 'UNITY_FAILED', origin: 'https://game.example' }]);
  }
});

test('context loss is terminal even if the loader resolves afterward', async () => {
  let resolve;
  const promise = new Promise(r => { resolve = r; });
  const { window, canvas, messages, listeners, context } = setup(() => promise);
  window.initUnityEngine(canvas);
  listeners.webglcontextlost();
  resolve({ Module: {}, SendMessage() {} });
  await tick();
  assert.equal(context.unityInstance, null);
  assert.equal(canvas.style.visibility, 'hidden');
  assert.equal(messages.length, 1);
  window.initUnityEngine(canvas);
  await tick();
  assert.equal(context.unityStartupState, 'failed');
});
