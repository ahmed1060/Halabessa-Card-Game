import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_config.dart';
import '../../../../core/widgets/background_decode_size.dart';
import '../../../home/presentation/providers/store_provider.dart';
import 'table_style.dart';

/// The same approved table artwork beneath either card renderer.
///
/// Unity's transparent card canvas lives behind the Navigator. Keeping this
/// artwork beneath that canvas avoids hiding the table with Flutter's HUD.
class GameTableBackground extends ConsumerWidget {
  const GameTableBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTable = ref.watch(activeTableSkinProvider);
    final viewport = MediaQuery.sizeOf(context);
    if (activeTable.id == 'default_table') {
      return RepaintBoundary(
        child: Image.asset(
          viewport.width < viewport.height
              ? 'assets/images/tables/halabessa_tabletop_portrait_v1.png'
              : 'assets/images/tables/halabessa_tabletop_landscape_v1.png',
          fit: BoxFit.fill,
          cacheWidth: backgroundDecodeWidth(
            viewport.width,
            MediaQuery.devicePixelRatioOf(context),
          ),
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: TableStyle.felt),
        ),
      );
    }
    return activeTable.assetPath.startsWith('http')
        ? Image.network(
            activeTable.assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: ThemeConfig.boardGreen),
          )
        : Image.asset(
            activeTable.assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: ThemeConfig.boardGreen),
          );
  }
}
