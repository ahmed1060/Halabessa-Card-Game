// Execute the actual host script in a minimal DOM fixture, with no browser IO.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync('web/index.html', 'utf8');
const script = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
function fixture() {
  const handlers = {}, forwarded = [], notices = [];
  const window = { location: {origin: 'http://localhost:9107'},
    addEventListener: (event, cb) => {handlers[event] = cb;}, postMessage: msg => notices.push(msg) };
  const context = vm.createContext({window, console: {error() {}, log() {}}, Promise, JSON, Date});
  vm.runInContext(script, context);
  const payload = {objectName: 'UnityBridge', methodName: 'OnFlutterMessage', message: '{"type":"SYNC_STATE"}'};
  const receive = (origin = window.location.origin, source = window, data = payload) =>
    handlers.message({origin, source, data: JSON.stringify(data)});
  return {context, window, forwarded, notices, receive};
}
let f = fixture();
f.context.unityStartupState = 'starting';
f.receive('https://foreign.example'); f.receive(undefined, {});
f.receive(undefined, undefined, {objectName: 'Other', methodName: 'OnFlutterMessage'});
assert.equal(f.context.pendingUnityBridgeMessages.length, 0);
f.receive();
assert.equal(f.context.pendingUnityBridgeMessages.length, 1);
f.context.unityInstance = {SendMessage: (...args) => f.forwarded.push(args)};
f.context.unityStartupState = 'running';
vm.runInContext('var pending = pendingUnityBridgeMessages; pendingUnityBridgeMessages = []; pending.forEach(forwardUnityBridgeMessage);', f.context);
assert.equal(f.forwarded.length, 1);
assert.equal(f.forwarded[0][2], '{"type":"SYNC_STATE"}');
f.receive(); assert.equal(f.forwarded.length, 2);
f = fixture(); f.context.unityStartupState = 'starting';
for (let i = 0; i < 9; i++) f.receive();
assert.equal(f.context.unityStartupState, 'failed');
assert.equal(f.context.pendingUnityBridgeMessages.length, 0);
assert.equal(JSON.parse(f.notices[0]).event, 'UNITY_FAILED');
f.receive(); assert.equal(f.context.pendingUnityBridgeMessages.length, 0);
console.log('PASS: host origin/source/method guards, initial snapshot buffering, running delivery and bounded fallback');
