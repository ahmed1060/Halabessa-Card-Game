import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class WebPlatformService {
  static bool get isMobile {
    if (!kIsWeb) return false;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('mobi') || 
           userAgent.contains('android') || 
           userAgent.contains('iphone') || 
           userAgent.contains('ipad') || 
           userAgent.contains('ipod');
  }

  static void enterFullscreenIfMobile() {
    if (!isMobile) return;
    
    try {
      final doc = html.document.documentElement;
      if (doc != null) {
        doc.requestFullscreen();
      }
    } catch (e) {
      debugPrint('Fullscreen request failed: $e');
    }
  }

  /// Sets up a one-time listener for the first user interaction to trigger fullscreen
  static void setupOneTimeFullscreenTrigger() {
    if (!isMobile) return;

    StreamSubscription? sub;
    sub = html.window.onClick.listen((event) {
      enterFullscreenIfMobile();
      sub?.cancel();
    });
    
    StreamSubscription? touchSub;
    touchSub = html.window.onTouchStart.listen((event) {
      enterFullscreenIfMobile();
      touchSub?.cancel();
    });
  }
}
