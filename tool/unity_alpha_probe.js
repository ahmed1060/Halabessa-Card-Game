// QA-only GL call trace. Loaded into the isolated fixture, never the app host.
(() => {
  const start = window.initUnityEngine;
  window.initUnityEngine = canvas => {
    const getContext = canvas.getContext.bind(canvas);
    let traced = false;
    canvas.getContext = (...args) => {
      const gl = getContext(...args);
      if (!gl || traced || !args[0].startsWith('webgl')) return gl;
      traced = true;
      let framebuffer = null, color = [], mask = [];
      const calls = [];
      const record = (type, value) => {
        calls.push({type, value});
        if (calls.length > 16) calls.shift();
      };
      for (const method of ['clearColor', 'colorMask', 'bindFramebuffer', 'clear']) {
        const original = gl[method].bind(gl);
        gl[method] = (...values) => {
          if (method === 'clearColor') color = values;
          if (method === 'colorMask') mask = values;
          if (method === 'bindFramebuffer') framebuffer = values[1];
          if (method === 'clear' && framebuffer === null) record('defaultClear', {color, mask, bits: values[0]});
          return original(...values);
        };
      }
      setTimeout(() => console.log('LOCAL_ALPHA_TRACE', JSON.stringify(calls)), 5000);
      return gl;
    };
    start(canvas);
  };
})();
