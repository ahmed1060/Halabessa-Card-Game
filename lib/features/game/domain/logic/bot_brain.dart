import '../models/match_state.dart';
import '../models/card.dart' as game_card;
import '../models/game_action.dart';
import 'dart:math';

class BotBrain {
  
  /// Evaluates the current state and returns a PlayCardAction for the given bot.
  static PlayCardAction decidePlay(MatchState state, String botId) {
    final hand = state.handCards[botId];
    if (hand == null || hand.isEmpty) {
      throw Exception('Bot $botId has no cards to play.');
    }

    final board = state.board;
    final random = Random();
    
    // HEURISTIC 1: Can I capture?
    if (board.isNotEmpty) {
      final topRank = board.last.rank;
      final matchingCards = hand.where((c) => c.rank == topRank).toList();
      
      if (matchingCards.isNotEmpty) {
        // Special Tafweet Strategy: If I have multiple matches, maybe bait?
        bool isTafweetMode = state.mode == GameMode.tafweet;
        if (isTafweetMode && matchingCards.length >= 2 && hand.length > 1) {
          final nonMatching = hand.where((c) => c.rank != topRank).toList();
          if (nonMatching.isNotEmpty && random.nextDouble() < 0.3) {
            // Bait bait bait!
            return PlayCardAction(botId, nonMatching[random.nextInt(nonMatching.length)]);
          }
        }

        // Standard Capture logic (95% success rate to simulate human error)
        if (random.nextDouble() > 0.05) {
          return PlayCardAction(botId, matchingCards[random.nextInt(matchingCards.length)]);
        }
      }
    }

    // HEURISTIC 2: Duplicate management
    // If I have duplicates, playing one might set up a capture for myself later.
    final rankCounts = <game_card.Rank, int>{};
    for (var c in hand) {
      rankCounts[c.rank] = (rankCounts[c.rank] ?? 0) + 1;
    }
    final duplicates = hand.where((c) => rankCounts[c.rank]! > 1).toList();
    if (duplicates.isNotEmpty && random.nextDouble() < 0.7) {
       return PlayCardAction(botId, duplicates[random.nextInt(duplicates.length)]);
    }

    // HEURISTIC 3: Avoid giving easy points (Advanced)
    // Don't play a card that the opponent likely has (hard to know without counting, but we can guess)

    // FALLBACK: Play a random card.
    return PlayCardAction(botId, hand[random.nextInt(hand.length)]);
  }

  /// Decides a cut point for the deck.
  static int decideCut(int deckCount) {
    if (deckCount <= 6) return 1;
    return 3 + Random().nextInt(deckCount - 6);
  }

  /// Decides whether to vote for shuffle.
  static bool decideShuffleVote(MatchState state, String botId) {
    // Bots usually follow the human majority or random if no humans voted.
    final currentVotes = state.shuffleVotes;
    final humanVotes = currentVotes.entries
        .where((e) => !e.key.startsWith('bot_'))
        .map((e) => e.value)
        .toList();
    
    if (humanVotes.isEmpty) {
      return Random().nextDouble() < 0.2; // 20% default
    }
    
    int yesCount = humanVotes.where((v) => v == true).length;
    int noCount = humanVotes.length - yesCount;
    
    if (yesCount > noCount) return true;
    if (noCount > yesCount) return false;
    
    return Random().nextBool();
  }

  /// Decides whether to vote for rematch.
  static bool decideRematchVote() {
    // Bots always want to play!
    return true; 
  }
}
