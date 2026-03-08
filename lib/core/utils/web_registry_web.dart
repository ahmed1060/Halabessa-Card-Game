import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

void registerWebUnityView() {
  ui_web.platformViewRegistry.registerViewFactory('unity-web-view', (int viewId) {
    final canvas = html.document.getElementById('unity-canvas');
    if (canvas != null) {
      // Allow Flutter to position the canvas
      canvas.style.position = 'unset';
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      // Reset z-index so it doesn't float over the UI
      canvas.style.zIndex = '0';
      return canvas;
    }
    return html.DivElement()..text = 'Unity Canvas Not Found in DOM';
  });
}
