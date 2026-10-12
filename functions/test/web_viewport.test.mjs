import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '')
  .replace(/startGame\(\);\s*$/, '');
function setup(viewport = { width: 430, height: 740, pageLeft: 0, pageTop: 0 }) {
  const host = { style: {} }, events = {}, viewportEvents = {}, frames = [];
  const browser = { innerWidth: 430, innerHeight: 932, scrollX: 0, scrollY: 0,
    visualViewport: viewport && { ...viewport, addEventListener(name, handler) { viewportEvents[name] = handler; } },
    addEventListener(name, handler) { events[name] = handler; },
    requestAnimationFrame(handler) { frames.push(handler); },
  };
  const context = vm.createContext({ window: browser, navigator: {}, console,
    document: { getElementById: () => host }, URL });
  vm.runInContext(source, context);
  context.configureGameViewport(host, browser);
  return { host, browser, context, events, viewportEvents, frames,
    flush() { for (const frame of frames.splice(0)) frame(); } };
}

test('host uses visible CSS pixels, not device height or device pixel ratio', () => {
  const f = setup();
  assert.deepEqual(f.host.style, { left: '0px', top: '0px', width: '430px', height: '740px' });
  assert.equal(f.host.style.transform, undefined);
});
test('first paint corrects initial dimensions without waiting for rotation', () => {
  const f = setup();
  Object.assign(f.browser.visualViewport, { height: 800, pageTop: 12 });
  f.flush();
  assert.equal(f.host.style.height, '800px');
  assert.equal(f.host.style.top, '12px');
  Object.assign(f.browser.visualViewport, { height: 740, pageTop: 0 });
  f.events.load(); f.flush();
  assert.equal(f.host.style.height, '740px');
  assert.equal(f.host.style.top, '0px');
});
test('keyboard pan/close and toolbar changes move and resize the same real host', () => {
  const f = setup();
  Object.assign(f.browser.visualViewport, { pageTop: 190, height: 390 });
  f.viewportEvents.scroll(); f.viewportEvents.resize(); f.flush();
  assert.equal(f.host.style.top, '190px');
  assert.equal(f.host.style.height, '390px');
  Object.assign(f.browser.visualViewport, { pageTop: 0, height: 740 });
  f.viewportEvents.scroll(); f.viewportEvents.resize(); f.flush();
  assert.equal(f.host.style.top, '0px');
  assert.equal(f.host.style.height, '740px');
});
test('rotation and page resume preserve the viewport origin and new dimensions', () => {
  const f = setup();
  Object.assign(f.browser.visualViewport, { width: 852, height: 393, pageLeft: 4, pageTop: 8 });
  f.events.orientationchange(); f.events.pageshow(); f.flush();
  assert.deepEqual(f.host.style, { left: '4px', top: '8px', width: '852px', height: '393px' });
});
test('offset fallback includes document scroll exactly once and never rewrites pointer events', () => {
  const f = setup({ width: 215, height: 370, offsetTop: 20, offsetLeft: 5, scale: 2 });
  f.browser.scrollY = 100; f.browser.scrollX = 10;
  f.viewportEvents.scroll(); f.flush();
  assert.equal(f.host.style.top, '120px'); assert.equal(f.host.style.left, '15px');
  assert.equal(f.host.style.width, '215px');
  assert.equal(f.events.pointerdown, undefined); assert.equal(f.events.touchstart, undefined);
  assert.equal(f.host.style.transform, undefined);
});
test('browsers without VisualViewport use window dimensions and scroll', () => {
  const f = setup(null);
  f.browser.innerHeight = 600; f.browser.scrollY = 15;
  f.events.resize(); f.flush();
  assert.equal(f.host.style.height, '600px'); assert.equal(f.host.style.top, '15px');
});
test('resize bursts coalesce and invalid transient bounds do not blank the app', () => {
  const f = setup();
  f.events.resize(); f.events.scroll(); f.viewportEvents.resize();
  assert.equal(f.frames.length, 1);
  f.browser.visualViewport.height = 0; f.flush();
  assert.equal(f.host.style.height, '740px');
  f.browser.visualViewport.height = 700; f.events.resize(); f.flush();
  assert.equal(f.host.style.height, '700px');
});
test('Flutter initializes with the same sized host rather than fixing the page body', async () => {
  const f = setup(); let running = false, received;
  f.context._flutter = { loader: { async load(options) {
    await options.onEntrypointLoaded({ async initializeEngine(config) {
      received = config.hostElement;
      return { async runApp() { running = true; } };
    } });
  } } };
  await f.context.startGame();
  assert.equal(received, f.host); assert.equal(running, true);
  const html = readFileSync(new URL('../../web/index.html', import.meta.url), 'utf8');
  assert.match(html, /id="game-host"/);
  assert.doesNotMatch(html, /height=device-height|user-scalable=no/);
});
