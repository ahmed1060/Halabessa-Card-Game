// Preserve the hybrid overlay's rendered alpha, not a colour-keyed background.
mergeInto(LibraryManager.library, {
  glClear: function (mask) {
    if (Module.halabessaTransparentOverlay === true && mask === 0x4000 &&
        GLctx.getParameter(GLctx.FRAMEBUFFER_BINDING) === null) {
      var channels = GLctx.getParameter(GLctx.COLOR_WRITEMASK);
      if (!channels[0] && !channels[1] && !channels[2] && channels[3] &&
          GLctx.getParameter(GLctx.COLOR_CLEAR_VALUE)[3] === 1) {
        // Unity's final opaque alpha-only backbuffer clear. Keep the camera's
        // alpha instead. Normal camera clears and offscreen buffers still run.
        return;
      }
    }
    GLctx.clear(mask);
  }
});
