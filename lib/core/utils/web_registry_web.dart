import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

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
      ..style.pointerEvents = 'auto'
      ..style.zIndex = '0';

    // Wait 200ms to ensure the element is in the DOM before Unity tries to bind to it
    Future.delayed(const Duration(milliseconds: 200), () {
      try {
        js.context.callMethod('initUnityEngine', [canvas]);
      } catch (e) {
        print("Error initializing Unity engine on canvas: $e");
      }
    });

    return canvas;
  });
}
