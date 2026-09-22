import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/global_settings_provider.dart';
import '../../features/home/presentation/providers/store_provider.dart';

class AssetPreloaderService {
  final Ref _ref;
  final _audioCache = AudioPlayer();

  AssetPreloaderService(this._ref);

  final _loadProgressController = StreamController<double>.broadcast();
  Stream<double> get loadProgress => _loadProgressController.stream;

  Future<void> preloadAll(BuildContext context) async {
    debugPrint('PRELOADER: Starting asset preloading...');
    final startTime = DateTime.now();
    _loadProgressController.add(0.0);

    final List<String> imageAssets = [
      // Essential
      'assets/images/gaming/game_logo.png',
      'assets/images/gaming/login_bg.png',
      'assets/images/items/ticket.png',
      
      // Avatars
      'assets/images/avatars/avatar1.png',
      'assets/images/avatars/avatar2.png',
      'assets/images/avatars/avatar3.png',
      'assets/images/avatars/avatar4.png',
      'assets/images/avatars/avatar5.png',
      'assets/images/avatars/avatar6.png',

      // Tables
      'assets/images/tables/table_skin_ancient_marble.png',
      'assets/images/tables/table_skin_golden_oasis.png',
      'assets/images/tables/table_skin_midnight_cyber.png',
      'assets/images/tables/table_skin_oceanic_depths.png',
      'assets/images/tables/table_skin_royal_velvet.png',

      // Cards (Royal is default)
      'assets/images/cards/royal/card_back_royal.png',
      'assets/images/cards/royal/card_front_royal_bg.png',
      'assets/images/cards/royal/card_seven_royal.png',
    ];

    // Collect Store Items
    try {
      final storeNotifier = _ref.read(storeProvider.notifier);
      final allItems = storeNotifier.allItems;
      for (var item in allItems) {
        if (!imageAssets.contains(item.assetPath)) imageAssets.add(item.assetPath);
        if (item.frontSkinPath != null && !imageAssets.contains(item.frontSkinPath!)) {
          imageAssets.add(item.frontSkinPath!);
        }
        if (item.faceIllustrations != null) {
          for (var path in item.faceIllustrations!.values) {
             if (!imageAssets.contains(path)) imageAssets.add(path);
          }
        }
      }
    } catch (e) {
      debugPrint('PRELOADER: Store items collection failed: $e');
    }

    int loadedCount = 0;
    final int total = imageAssets.length;

    await Future.wait(imageAssets.map((path) async {
      try {
        if (context.mounted) {
          await precacheImage(AssetImage(path), context).catchError((_) => null);
        }
      } catch (_) {}
      loadedCount++;
      _loadProgressController.add(loadedCount / total);
    }));

    // Audio Pre-caching (Simplified)
    try {
      final globalSettings = _ref.read(globalSettingsProvider);
      if (globalSettings.musicOverrideUrl != null) {
        await _audioCache
            .setSourceUrl(globalSettings.musicOverrideUrl!)
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {}

    final duration = DateTime.now().difference(startTime);
    debugPrint('PRELOADER: Preloading finished in ${duration.inMilliseconds}ms');
    _loadProgressController.add(1.0);
  }

  void dispose() {
    _audioCache.dispose();
    _loadProgressController.close();
  }
}

final assetPreloaderServiceProvider = Provider<AssetPreloaderService>((ref) {
  final service = AssetPreloaderService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
