import 'package:flutter/material.dart';
import '../theme/theme_config.dart';
import 'background_decode_size.dart';
import '../../features/game/presentation/widgets/match_table_layout.dart';

/// One cafe frame for every screen family. All controls remain real widgets;
/// illustration never contains labels, balances, names, or interaction targets.
class LanternPageFrame extends StatelessWidget {
  final Widget child;
  const LanternPageFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(child: Image.asset(
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
            ? 'assets/images/tables/lantern_nights_v1.png'
            : 'assets/images/tables/lantern_nights_portrait_v2.png',
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        cacheWidth: backgroundDecodeWidth(MediaQuery.sizeOf(context).width,
          MediaQuery.devicePixelRatioOf(context)),
      )),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .26, .48, 1],
            colors: [
              Color(0x22192638),
              Color(0x443B274C),
              Color(0xE63B274C),
              ThemeConfig.darkBg,
            ],
          ),
        ),
      ),
      child,
    ],
  );
}

class LanternPageTitle extends StatelessWidget {
  final String title;
  const LanternPageTitle({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 52, child: FittedBox(child: LanternWordmark())),
      const SizedBox(height: 8),
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFFF6E7),
        ),
      ),
    ],
  );
}
