import 'dart:html' as html;

class WebUtils {
  static void postMessage(dynamic data, String target) {
    html.window.postMessage(data, target);
  }
  
  static Stream<html.MessageEvent> get onMessage => html.window.onMessage;
  static html.Window get window => html.window;
  static html.HtmlDocument get document => html.document;
}
