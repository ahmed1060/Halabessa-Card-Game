import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/game/domain/models/card.dart' as game;
import '../../features/game/presentation/widgets/lantern_card_art.dart';
import 'lantern_page_frame.dart';

/// Explanations reflect the existing rank-match rules, not another card game.
class LanternHelpScreen extends StatelessWidget {
  const LanternHelpScreen({super.key});
  @override
  Widget build(BuildContext context) => LanternPageFrame(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        toolbarHeight: 110,
        title: LanternPageTitle(title: 'help_title'.tr()),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0D1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final suit in [
                            game.Suit.hearts,
                            game.Suit.clubs,
                          ])
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: LanternCardArt(
                                card: game.Card(suit, game.Rank.seven),
                                faceUp: true,
                                width: 70,
                                height: 100,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        'help_capture'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF192638),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final key in ['help_team', 'help_history', 'help_dealer'])
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF192638),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      key.tr(),
                      style: const TextStyle(
                        color: Color(0xFFFFF0D1),
                        fontSize: 16,
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
