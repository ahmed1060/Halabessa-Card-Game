// Stub for Web-specific APIs on Native platforms
class WebUtils {
  static void postMessage(dynamic data, String target) {}
  static Stream<dynamic>? get onMessage => null;
  static dynamic get window => null;
  static dynamic get document => null;
}
