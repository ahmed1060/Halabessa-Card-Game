import 'card.dart' as game_card;

class Capture {
  final game_card.Card leadingCard;
  final List<game_card.Card> capturedCards;

  const Capture({
    required this.leadingCard,
    required this.capturedCards,
  });

  Map<String, dynamic> toJson() => {
        'leadingCard': leadingCard.toJson(),
        'capturedCards': capturedCards.map((c) => c.toJson()).toList(),
      };

  factory Capture.fromJson(Map<String, dynamic> json) {
    return Capture(
      leadingCard: game_card.Card.fromJson(Map<String, dynamic>.from(json['leadingCard'] as Map)),
      capturedCards: (json['capturedCards'] as List)
          .map((c) => game_card.Card.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
    );
  }
}
