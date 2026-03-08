import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

void registerWebUnityView() {
  ui_web.platformViewRegistry.registerViewFactory('unity-web-view', (int viewId) {
    // Dynamically create the canvas so it isn't ripped from the DOM root later
    final canvas = html.CanvasElement(id: 'unity-canvas-$viewId')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.background = 'transparent'
      ..style.backgroundColor = 'transparent'
      ..style.pointerEvents = 'auto'
      ..style.zIndex = '0';

    // Wait a brief moment for Flutter to physically attach this canvas to the DOM
    html.window.setTimeout(() {
      try {
        html.window.callMethod('initUnityEngine', [canvas]);
      } catch (e) {
        print("Error initializing Unity engine on canvas: $e");
      }
    }, 100);

    return canvas;
  });
}
