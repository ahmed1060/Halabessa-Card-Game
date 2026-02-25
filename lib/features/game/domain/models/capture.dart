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
    // Ultra-defensive parsing to avoid TypeError: null: type '...' is not a subtype of type 'Map'
    final leadingCardData = json['leadingCard'];
    final capturedCardsData = json['capturedCards'];

    return Capture(
      leadingCard: (leadingCardData is Map)
          ? game_card.Card.fromJson(Map<String, dynamic>.from(leadingCardData))
          : const game_card.Card(game_card.Suit.hearts, game_card.Rank.ace), // Safe fallback
      capturedCards: (capturedCardsData is List)
          ? capturedCardsData
              .map((c) => c is Map ? game_card.Card.fromJson(Map<String, dynamic>.from(c)) : null)
              .whereType<game_card.Card>()
              .toList()
          : [],
    );
  }
}
