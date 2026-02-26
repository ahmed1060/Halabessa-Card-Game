import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';

import '../../domain/models/card.dart' as game_card;

class CardWidget extends StatelessWidget {
  final game_card.Card card;
  final bool isFaceUp;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const CardWidget({
    super.key,
    required this.card,
    this.isFaceUp = true,
    this.width = 70,
    this.height = 100,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: PlayingCardView(
          card: PlayingCard(
             _mapSuit(card.suit),
             _mapRank(card.rank),
          ),
          showBack: !isFaceUp,
          style: PlayingCardViewStyle(
            cardBackContentBuilder: (context) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/card_back_premium.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(10),
             side: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          elevation: 8.0,
        ),
      ),
    );
  }

  Suit _mapSuit(game_card.Suit suit) {
    switch (suit) {
      case game_card.Suit.hearts: return Suit.hearts;
      case game_card.Suit.diamonds: return Suit.diamonds;
      case game_card.Suit.clubs: return Suit.clubs;
      case game_card.Suit.spades: return Suit.spades;
    }
  }

  CardValue _mapRank(game_card.Rank rank) {
    switch (rank) {
      case game_card.Rank.two: return CardValue.two;
      case game_card.Rank.three: return CardValue.three;
      case game_card.Rank.four: return CardValue.four;
      case game_card.Rank.five: return CardValue.five;
      case game_card.Rank.six: return CardValue.six;
      case game_card.Rank.seven: return CardValue.seven;
      case game_card.Rank.eight: return CardValue.eight;
      case game_card.Rank.nine: return CardValue.nine;
      case game_card.Rank.ten: return CardValue.ten;
      case game_card.Rank.jack: return CardValue.jack;
      case game_card.Rank.queen: return CardValue.queen;
      case game_card.Rank.king: return CardValue.king;
      case game_card.Rank.ace: return CardValue.ace;
    }
  }
}
