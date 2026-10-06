import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../features/game/presentation/widgets/table_style.dart';

enum LanternDestination { home, play, collection, leaderboard, profile }

/// Main-game navigation only. Never mounted over an active match.
class LanternNavigationDock extends StatelessWidget {
  final LanternDestination selected;
  const LanternNavigationDock({super.key, required this.selected});
  static const routes = [
    '/home',
    '/play',
    '/collection',
    '/leaderboard',
    '/profile',
  ];
  static const labels = [
    'ui_home',
    'ui_play',
    'inventory_title',
    'leaderboard_title',
    'player_profile',
  ];
  static const icons = [
    Icons.home_rounded,
    Icons.groups_rounded,
    Icons.style_rounded,
    Icons.emoji_events_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: TableStyle.ink,
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                for (final destination in LanternDestination.values)
                  Expanded(
                    child: Semantics(
                      selected: destination == selected,
                      child: Tooltip(
                        message: labels[destination.index].tr(),
                        child: InkWell(
                          key: ValueKey('dock-${destination.name}'),
                          onTap: destination == selected
                              ? null
                              : () => Navigator.pushReplacementNamed(
                                  context,
                                  routes[destination.index],
                                ),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: destination == selected
                                  ? TableStyle.brass.withValues(alpha: .15)
                                  : null,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: destination == selected
                                    ? TableStyle.brass
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icons[destination.index],
                                  color: destination == selected
                                      ? TableStyle.brass
                                      : TableStyle.ivory,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  labels[destination.index].tr(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TableStyle.detail.copyWith(
                                    fontSize: 10,
                                    color: destination == selected
                                        ? TableStyle.brass
                                        : TableStyle.ivory,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
