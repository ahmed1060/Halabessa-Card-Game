// Test the actual WebGL plugin without a browser or Unity player.
const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const library = {}, clears = [];
const gl = {FRAMEBUFFER_BINDING: 1, COLOR_WRITEMASK: 2, COLOR_CLEAR_VALUE: 3,
  getParameter: key => values[key], clear: bits => clears.push(bits)};
let values = {1: null, 2: [false, false, false, true], 3: [1, 0, 0, 1]};
const moduleFixture = {halabessaTransparentOverlay: true};
vm.runInNewContext(fs.readFileSync('unity/Halabessa/Assets/Plugins/WebGL/HalabessaTransparency.jslib','utf8'),
  {Module: moduleFixture, GLctx: gl, LibraryManager: {library}, mergeInto: Object.assign});
library.glClear(0x4000); assert.equal(clears.length, 0);
values[2] = [true, true, true, true]; library.glClear(0x4000);
values[2] = [false, false, false, true]; values[1] = {}; library.glClear(0x4000);
values[1] = null; values[3][3] = 0; library.glClear(0x4000);
values[3][3] = 1; library.glClear(0x4100);
moduleFixture.halabessaTransparentOverlay = false; library.glClear(0x4000);
assert.deepEqual(clears, [0x4000,0x4000,0x4000,0x4100,0x4000]);
console.log('PASS: only opted-in opaque alpha-only default-buffer clear is skipped');
