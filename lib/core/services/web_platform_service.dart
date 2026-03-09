import 'dart:async';
import 'package:halabessa/core/utils/web_utils.dart';
import 'package:flutter/foundation.dart';

class WebPlatformService {
  static bool get isMobile {
    if (!kIsWeb) return false;
    final dynamic window = WebUtils.window;
    if (window == null) return false;
    final userAgent = window.navigator.userAgent.toLowerCase();
    return userAgent.contains('mobi') || 
           userAgent.contains('android') || 
           userAgent.contains('iphone') || 
           userAgent.contains('ipad') || 
           userAgent.contains('ipod');
  }

  static void enterFullscreenIfMobile() {
    if (!isMobile) return;
    
    try {
      final doc = WebUtils.document;
      if (doc != null) {
        doc.documentElement?.requestFullscreen();
      }
    } catch (e) {
      debugPrint('Fullscreen request failed: $e');
    }
  }

  /// Sets up a one-time listener for the first user interaction to trigger fullscreen
  static void setupOneTimeFullscreenTrigger() {
    if (!isMobile) return;

    final window = WebUtils.window;
    if (window == null) return;

    StreamSubscription? sub;
    sub = window.onClick.listen((event) {
      enterFullscreenIfMobile();
      sub?.cancel();
    });
    
    StreamSubscription? touchSub;
    touchSub = window.onTouchStart.listen((event) {
      enterFullscreenIfMobile();
      touchSub?.cancel();
    });
  }
}
