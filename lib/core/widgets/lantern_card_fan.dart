import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../features/game/domain/models/card.dart' as game;
import '../../features/game/presentation/widgets/lantern_card_art.dart';

/// Decorative recovery/welcome artwork, never an interaction target or hand.
class LanternCardFan extends StatelessWidget {
  const LanternCardFan({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 220,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var index = 0; index < 5; index++)
            Transform.translate(
              offset: Offset((index - 2) * 26, (index - 2).abs() * 5),
              child: Transform.rotate(
                angle: (index - 2) * math.pi / 18,
                child: const LanternCardArt(
                  card: game.Card(game.Suit.spades, game.Rank.ace),
                  faceUp: false,
                  width: 76,
                  height: 110,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
