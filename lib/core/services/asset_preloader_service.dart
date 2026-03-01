import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/global_settings_provider.dart';
import '../../features/home/presentation/providers/store_provider.dart';

class AssetPreloaderService {
  final Ref _ref;
  final _audioCache = AudioPlayer(); // Used for pre-fetching audio

  AssetPreloaderService(this._ref);

  Future<void> preloadAll(BuildContext context) async {
    debugPrint('PRELOADER: Starting asset preloading...');
    
    final startTime = DateTime.now();

    // 1. Precache Essential Images
    if (!context.mounted) return;
    await Future.wait([
      precacheImage(const AssetImage('assets/images/logo.png'), context),
      precacheImage(const AssetImage('assets/images/items/ticket.png'), context),
      // Precache Default Music if exists
      _audioCache.setSource(AssetSource('music/bg_music.mp3')), 
    ]);

    // 2. Precache Cards (Partial/High priority)
    // We could loop through all but let's do critical ones
    final cardPaths = [
      'assets/images/cards/royal/card_back_royal.png',
      'assets/images/cards/royal/card_front_royal_bg.png',
      // Add more as needed
    ];
    
    for (var path in cardPaths) {
      if (!context.mounted) return;
      precacheImage(AssetImage(path), context);
    }

    // 3. Precache Store Items (Avatars, Skins)
    try {
      final storeNotifier = _ref.read(storeProvider.notifier);
      final allItems = storeNotifier.allItems;
      
      for (var item in allItems) {
        if (!context.mounted) return;
        
        // Main Asset
        precacheImage(AssetImage(item.assetPath), context);
        
        // Front Skin Asset (if applicable)
        if (item.frontSkinPath != null) {
          precacheImage(AssetImage(item.frontSkinPath!), context);
        }
        
        // Face Illustrations (if applicable)
        if (item.faceIllustrations != null) {
          for (var path in item.faceIllustrations!.values) {
             precacheImage(AssetImage(path), context);
          }
        }
      }
    } catch (e) {
      debugPrint('PRELOADER: Failed to precache some store items: $e');
    }

    // 4. Precache Remote Audio Overrides
    final globalSettings = _ref.read(globalSettingsProvider);
    if (globalSettings.musicOverrideUrl != null) {
      await _audioCache.setSourceUrl(globalSettings.musicOverrideUrl!);
    }
    
    for (var url in globalSettings.sfxOverrides.values) {
      await _audioCache.setSourceUrl(url);
    }

    final duration = DateTime.now().difference(startTime);
    debugPrint('PRELOADER: Preloading finished in ${duration.inMilliseconds}ms');
  }

  void dispose() {
    _audioCache.dispose();
  }
}

final assetPreloaderServiceProvider = Provider<AssetPreloaderService>((ref) {
  final service = AssetPreloaderService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
