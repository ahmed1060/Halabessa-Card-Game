import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import '../../features/game/domain/models/card.dart' as game;
import '../../features/game/presentation/widgets/lantern_card_art.dart';
import '../../features/game/presentation/widgets/table_style.dart';
import 'lantern_page_frame.dart';
import 'lantern_panel.dart';

/// Illustrated rules use rank matching, never the older suit-based draft.
class LanternHelpScreen extends StatelessWidget {
  const LanternHelpScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: LanternPageFrame(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          centerTitle: true,
          toolbarHeight: 110,
          title: LanternPageTitle(title: 'help_title'.tr()),
          bottom: TabBar(
            isScrollable: true,
            labelColor: TableStyle.ink,
            unselectedLabelColor: TableStyle.ivory,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: TableStyle.brass,
              borderRadius: BorderRadius.circular(24),
            ),
            tabs: [
              for (final key in ['ui_basics', 'ui_capturing', 'ui_team_play'])
                Tab(text: key.tr()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _page(['ui_play_one', 'help_dealer'], example: true),
            _page(['help_capture', 'help_history'], example: true),
            _page(['help_team', 'help_history', 'help_dealer']),
          ],
        ),
      ),
    ),
  );

  Widget _page(List<String> keys, {bool example = false}) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final key in keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: LanternPanel(
                padding: const EdgeInsets.all(20),
                child: Text(
                  key.tr(),
                  style: TableStyle.label.copyWith(
                    color: TableStyle.ink,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          if (example) const _CaptureExample(),
        ],
      ),
    ),
  );
}

class _CaptureExample extends StatefulWidget {
  const _CaptureExample();
  @override
  State<_CaptureExample> createState() => _CaptureExampleState();
}

class _CaptureExampleState extends State<_CaptureExample> {
  bool _collected = false;
  @override
  Widget build(BuildContext context) => LanternPanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      children: [
        Text(
          'ui_capture_example'.tr(),
          textAlign: TextAlign.center,
          style: TableStyle.label.copyWith(color: TableStyle.ink),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            child: _collected
                ? const LanternCardArt(
                    key: ValueKey('example-collected'),
                    card: game.Card(game.Suit.hearts, game.Rank.seven),
                    faceUp: false,
                    width: 70,
                    height: 100,
                  )
                : const Row(
                    key: ValueKey('example-table'),
                    textDirection: ui.TextDirection.ltr,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LanternCardArt(
                        card: game.Card(game.Suit.spades, game.Rank.four),
                        faceUp: true,
                        width: 70,
                        height: 100,
                      ),
                      SizedBox(width: 8),
                      LanternCardArt(
                        card: game.Card(game.Suit.clubs, game.Rank.seven),
                        faceUp: true,
                        width: 70,
                        height: 100,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('help-capture-example'),
          style: FilledButton.styleFrom(
            backgroundColor: TableStyle.ink,
            foregroundColor: TableStyle.ivory,
          ),
          onPressed: () => setState(() => _collected = !_collected),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('ui_watch_example'.tr()),
        ),
      ],
    ),
  );
}
