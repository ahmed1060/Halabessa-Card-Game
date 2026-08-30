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

    // Increased delay to 1500ms to ensure the DOM has fully settled and painted
    Future.delayed(const Duration(milliseconds: 1500), () {
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
