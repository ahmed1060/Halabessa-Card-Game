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
