import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

void registerWebUnityView() {
  ui_web.platformViewRegistry.registerViewFactory('unity-web-view', (int viewId) {
    // The canvas is created here but its ID must match the CSS for positioning
    final canvas = html.CanvasElement()
      ..id = 'unity-canvas'
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.background = 'transparent'
      ..style.backgroundColor = 'transparent'
      ..style.pointerEvents = 'none'
      ..style.zIndex = '0';

    // Ensure full opacity so the WebGL canvas renders visibly when Flutter's layer is visible
    canvas.style.opacity = '1.0';

    // Boot Unity once the canvas is actually attached to the DOM with a
    // real layout size, instead of guessing a fixed delay: a fast first
    // paint wasted 1.5s, a slow one could still hand Unity a 0x0 GL
    // context because the element wasn't attached yet.
    var elapsedMs = 0;
    const pollIntervalMs = 50;
    const timeoutMs = 10000;
    Timer.periodic(const Duration(milliseconds: pollIntervalMs), (timer) {
      elapsedMs += pollIntervalMs;
      final attached = canvas.isConnected == true && canvas.clientWidth > 0 && canvas.clientHeight > 0;
      if (!attached && elapsedMs < timeoutMs) return;

      timer.cancel();
      if (!attached) {
        debugPrint("Unity canvas never attached with a non-zero size after ${timeoutMs}ms; booting anyway.");
      }
      try {
        js.context.callMethod('initUnityEngine', [canvas]);
      } catch (e) {
        debugPrint("Error initializing Unity engine on canvas: $e");
      }
    });

    return canvas;
  });
}

void setWebUnityPointerEvents(bool interactive) {
  try {
    final canvas = html.document.getElementById('unity-canvas');
    if (canvas != null) {
      canvas.style.pointerEvents = interactive ? 'auto' : 'none';
      if (!interactive) {
        canvas.blur();
      }
    }
  } catch (e) {
    debugPrint("Error setting Unity canvas pointer events: $e");
  }
}
