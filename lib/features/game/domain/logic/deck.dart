import '../models/card.dart' as game_card;
import '../models/capture.dart';

class Deck {
  final List<game_card.Card> cards;

  Deck(this.cards);

  factory Deck.standard() {
    final cards = <game_card.Card>[];
    for (final suit in game_card.Suit.values) {
      for (final rank in game_card.Rank.values) {
        cards.add(game_card.Card(suit, rank));
      }
    }
    return Deck(cards);
  }

  factory Deck.restoreFromHarvest(Map<String, List<Capture>> harvestStacks) {
    final restoredCards = <game_card.Card>[];
    
    // Process Team A then Team B
    if (harvestStacks.containsKey('teamA')) {
      for (var capture in harvestStacks['teamA']!) {
        restoredCards.addAll(capture.capturedCards);
        restoredCards.add(capture.leadingCard);
      }
    }
    if (harvestStacks.containsKey('teamB')) {
      for (var capture in harvestStacks['teamB']!) {
        restoredCards.addAll(capture.capturedCards);
        restoredCards.add(capture.leadingCard);
      }
    }
    return Deck(restoredCards);
  }

  /// RECONSTRUCTION: Rebuilds the hidden part of the deck by subtracting all visible cards 
  /// (Board + Hands + Harvested) from a standard 52-card deck.
  /// This is used when a new Host takes over or when rejoining a "hibernated" game.
  factory Deck.reconstructRemaining(
    List<game_card.Card> board,
    Map<String, List<game_card.Card>> hands,
    Map<String, List<Capture>> harvest,
  ) {
    // 1. Start with a full 52-card deck
    final fullDeck = Deck.standard().cards;
    
    // 2. Collect all "Visible/Accounted" card keys
    final visibleKeys = <String>{};
    
    for (var c in board) {
      visibleKeys.add(c.firebaseKey);
    }
    
    hands.forEach((playerId, hand) {
      for (var c in hand) {
        visibleKeys.add(c.firebaseKey);
      }
    });
    
    harvest.forEach((teamId, captures) {
      for (var capture in captures) {
        visibleKeys.add(capture.leadingCard.firebaseKey);
        for (var c in capture.capturedCards) {
          visibleKeys.add(c.firebaseKey);
        }
      }
    });

    // 3. Subtract visible cards to find the remaining hidden cards
    final remainingCards = fullDeck.where((c) => !visibleKeys.contains(c.firebaseKey)).toList();
    
    // Note: We don't shuffle here because the original order is lost,
    // but the remaining cards ARE the deck for the rest of this round.
    return Deck(remainingCards);
  }

  void shuffle() {
    cards.shuffle();
  }

  // "The Cut" mechanism: Take a random chunk from the top and put it at the bottom
  void cut(int position) {
    if (position <= 0 || position >= cards.length) return;
    
    final topHalf = cards.sublist(0, position);
    final bottomHalf = cards.sublist(position);
    
    cards.clear();
    cards.addAll(bottomHalf);
    cards.addAll(topHalf);
  }

  game_card.Card? draw() {
    if (cards.isEmpty) return null;
    return cards.removeLast();
  }

  // Helper method to draw exactly N cards
  List<game_card.Card> drawMultiple(int count) {
    final drawn = <game_card.Card>[];
    for (int i = 0; i < count; i++) {
        final c = draw();
        if (c != null) drawn.add(c);
    }
    return drawn;
  }

  game_card.Card get lastCardRevealed => cards.first; // Last card to be drawn (bottom of the deck conceptually)
  
  bool get isEmpty => cards.isEmpty;
  int get remaining => cards.length;
}
