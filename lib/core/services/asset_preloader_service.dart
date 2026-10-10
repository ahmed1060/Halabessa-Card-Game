import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/presentation/providers/store_provider.dart';

/// Startup warms only the visible theme, not the entire shop or remote music.
/// Other assets load normally when their screen/skin is selected.
Set<String> startupImagePaths({
  required bool landscape,
  required ShopItem table,
  required ShopItem cardBack,
}) => {
  landscape
      ? 'assets/images/tables/lantern_nights_v1.png'
      : 'assets/images/tables/lantern_nights_portrait_v2.png',
  table.assetPath,
  // Lantern cards are painted, so their old raster alternatives need no decode.
  if (cardBack.id != 'default_card') ...{
    cardBack.assetPath,
    if (cardBack.frontSkinPath != null) cardBack.frontSkinPath!,
    if (cardBack.aceSkinPath != null) cardBack.aceSkinPath!,
    if (cardBack.sevenDiamondSkinPath != null) cardBack.sevenDiamondSkinPath!,
    ...?cardBack.faceIllustrations?.values,
    ...?cardBack.suitIcons?.values,
  },
}..removeWhere((path) => path.isEmpty);

ImageProvider<Object> startupImageProvider(String path) =>
    path.startsWith('https://') || path.startsWith('http://')
    ? NetworkImage(path)
    : AssetImage(path);

class AssetPreloaderService {
  final Ref _ref;
  bool _disposed = false;
  AssetPreloaderService(this._ref);
  final _loadProgressController = StreamController<double>.broadcast();
  Stream<double> get loadProgress => _loadProgressController.stream;

  void _progress(double value) {
    if (!_disposed) _loadProgressController.add(value);
  }

  Future<void> preloadAll(BuildContext context) async {
    _progress(0);
    final paths = startupImagePaths(
      landscape:
          MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height,
      table: _ref.read(activeTableSkinProvider),
      cardBack: _ref.read(activeCardBackProvider),
    ).toList();
    var next = 0;
    var loaded = 0;
    var finished = false;
    Future<void> warm() async {
      while (!finished &&
          !_disposed &&
          context.mounted &&
          next < paths.length) {
        final path = paths[next++];
        try {
          await precacheImage(
            startupImageProvider(path),
            context,
            onError: (_, __) {},
          ).timeout(const Duration(seconds: 3));
        } catch (_) {
          // Loading UI must never require a catalogue/network asset to succeed.
        }
        if (!finished) _progress(++loaded / paths.length);
      }
    }

    // Limit simultaneous decodes. A slow custom skin cannot hold startup.
    try {
      await Future.wait([warm(), warm()]).timeout(const Duration(seconds: 4));
    } on TimeoutException {
      // Remaining artwork is loaded by its normal visible widget.
    } finally {
      finished = true;
      _progress(1);
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_loadProgressController.close());
  }
}

final assetPreloaderServiceProvider = Provider<AssetPreloaderService>((ref) {
  final service = AssetPreloaderService(ref);
  ref.onDispose(service.dispose);
  return service;
});
