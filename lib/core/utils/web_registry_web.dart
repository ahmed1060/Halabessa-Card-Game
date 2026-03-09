import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

void registerWebUnityView() {
  ui_web.platformViewRegistry.registerViewFactory('unity-web-view', (int viewId) {
    // Dynamically create the canvas so it isn't ripped from the DOM root later
    final canvas = html.CanvasElement()
      ..id = 'unity-canvas-$viewId'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '1px solid rgba(255, 255, 255, 0.1)'
      ..style.borderRadius = '20px'
      ..style.background = 'transparent'
      ..style.backgroundColor = 'transparent'
      ..style.pointerEvents = 'auto'
      ..style.zIndex = '0';

    // Wait a brief moment for Flutter to physically attach this canvas to the DOM
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        js.context.callMethod('initUnityEngine', [canvas]);
      } catch (e) {
        print("Error initializing Unity engine on canvas: $e");
      }
    });

    return canvas;
  });
}
