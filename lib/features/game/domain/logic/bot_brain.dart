import '../models/match_state.dart';
import '../models/card.dart' as game_card;
import '../models/game_action.dart';
import 'dart:math';

/// Result object returned by the advanced bot evaluation.
class BotDecision {
  final game_card.Card card;
  final String? emojiReaction;
  final String reason;

  const BotDecision(this.card, {this.emojiReaction, this.reason = ''});
}

/// Card tracking and counting memory for the bot.
/// Strictly computes only legally visible information (harvest stacks, active board,
/// bot's own hand, and the cut card) to ensure zero cheating.
class CardCountingMatrix {
  final Map<game_card.Rank, int> seenCounts;
  final Map<game_card.Rank, int> handCounts;
  final int totalCardsSeen;

  CardCountingMatrix({
    required this.seenCounts,
    required this.handCounts,
    required this.totalCardsSeen,
  });

  /// The number of unseen cards of this rank remaining in opponents' hands or undealt deck.
  int unseen(game_card.Rank rank) {
    final seen = seenCounts[rank] ?? 0;
    return (4 - seen).clamp(0, 4);
  }

  /// A "Dead Rank" (ورقة ميتة): Exactly 0 unseen cards remain.
  /// Neither the next opponent nor anyone else can match this rank!
  bool isDeadRank(game_card.Rank rank) => unseen(rank) == 0;

  /// Returns safety score where higher is safer (0 unseen is maximum safety).
  int dangerScore(game_card.Rank rank) => unseen(rank);

  factory CardCountingMatrix.fromState(MatchState state, String botId) {
    final seen = <game_card.Rank, int>{};
    final inHand = <game_card.Rank, int>{};

    void recordCard(game_card.Card card) {
      seen[card.rank] = (seen[card.rank] ?? 0) + 1;
    }

    // 1. Cards visible in harvest piles (face-up for all players)
    for (final teamCaptures in state.harvestStacks.values) {
      for (final capture in teamCaptures) {
        recordCard(capture.leadingCard);
        for (final c in capture.capturedCards) {
          recordCard(c);
        }
      }
    }

    // 2. Cards visible on the active board
    for (final c in state.board) {
      recordCard(c);
    }

    // 3. Cards in bot's own hand
    final myHand = state.handCards[botId] ?? [];
    for (final c in myHand) {
      recordCard(c);
      inHand[c.rank] = (inHand[c.rank] ?? 0) + 1;
    }

    int totalSeen = 0;
    for (final count in seen.values) {
      totalSeen += count;
    }

    return CardCountingMatrix(
      seenCounts: seen,
      handCounts: inHand,
      totalCardsSeen: totalSeen,
    );
  }
}

class BotBrain {
  
  /// Evaluates the current state and returns a PlayCardAction for the given bot.
  /// Preserves standard contract for backward compatibility.
  static PlayCardAction decidePlay(MatchState state, String botId) {
    final decision = decidePlayAdvanced(state, botId);
    return PlayCardAction(botId, decision.card);
  }

  /// Advanced strategic decision-making incorporating card counting, dead ranks,
  /// Tafweet risk/reward analysis, and emotional ahwa reactions.
  static BotDecision decidePlayAdvanced(MatchState state, String botId) {
    final hand = state.handCards[botId];
    if (hand == null || hand.isEmpty) {
      throw Exception('Bot $botId has no cards to play.');
    }

    final board = state.board;
    final random = Random();
    final matrix = CardCountingMatrix.fromState(state, botId);

    final int botIndex = state.playerIds.indexOf(botId);
    final String nextOpponentId = (botIndex >= 0 && state.playerIds.length == 4) 
        ? state.playerIds[(botIndex + 1) % 4] 
        : '';
    final String partnerId = (botIndex >= 0 && state.playerIds.length == 4) 
        ? state.playerIds[(botIndex + 2) % 4] 
        : '';

    // =========================================================================
    // 1. CAPTURE EVALUATION
    // =========================================================================
    if (board.isNotEmpty) {
      final topRank = board.last.rank;
      final matchingCards = hand.where((c) => c.rank == topRank).toList();

      if (matchingCards.isNotEmpty) {
        final bool isTafweetMode = state.mode == GameMode.tafweet;
        final bool isLowBoardRisk = board.length <= 2;
        final bool hasDuplicateMatch = matchingCards.length >= 2;
        final nonMatching = hand.where((c) => c.rank != topRank).toList();

        // Strategic Tafweet Baiting:
        // Only bait if:
        // 1. In Tafweet mode
        // 2. We hold at least 2 copies of the matching rank (so we can smash it later)
        // 3. Board is low risk (<= 2 cards, so if opponent takes it, loss is minimal)
        // 4. We have a safe alternative discard in hand
        if (isTafweetMode && hasDuplicateMatch && isLowBoardRisk && nonMatching.isNotEmpty) {
          if (random.nextDouble() < 0.35) {
            final baitCard = _selectBestDiscard(
              candidates: nonMatching,
              matrix: matrix,
              board: board,
              nextOpponentId: nextOpponentId,
              partnerId: partnerId,
              skippedMatches: state.skippedMatches,
              random: random,
            );
            return BotDecision(
              baitCard,
              emojiReaction: random.nextDouble() < 0.3 ? '👀' : null,
              reason: 'Tafweet bait trap: holding duplicate $topRank',
            );
          }
        }

        // Standard Capture execution (98% to account for slight human-like variance)
        if (random.nextDouble() < 0.98) {
          final cardToPlay = matchingCards.first;
          final bool isBasraSweep = board.length == 1;
          final bool isHugeHarvest = board.length >= 4;

          String? reaction;
          if (isBasraSweep && random.nextDouble() < 0.5) {
            reaction = const ['👑', '😎', '🔥', '💪'][random.nextInt(4)];
          } else if (isHugeHarvest && random.nextDouble() < 0.45) {
            reaction = const ['😋', '🔥', '🤑'][random.nextInt(3)];
          } else if (isTafweetMode && random.nextDouble() < 0.35) {
            reaction = const ['😂', '😎'][random.nextInt(2)];
          }

          return BotDecision(
            cardToPlay,
            emojiReaction: reaction,
            reason: 'Capture match on ${topRank.name}',
          );
        }
      }
    }

    // =========================================================================
    // 2. DISCARD EVALUATION (Card counting & dead-rank safety)
    // =========================================================================
    final chosenCard = _selectBestDiscard(
      candidates: hand,
      matrix: matrix,
      board: board,
      nextOpponentId: nextOpponentId,
      partnerId: partnerId,
      skippedMatches: state.skippedMatches,
      random: random,
    );

    // If forced into a risky discard with a stacked board, bot may express sweat
    String? discardReaction;
    if (board.length >= 3 && matrix.unseen(chosenCard.rank) >= 2 && random.nextDouble() < 0.3) {
      discardReaction = '🤔';
    }

    return BotDecision(
      chosenCard,
      emojiReaction: discardReaction,
      reason: 'Optimal counted discard: ${chosenCard.rank.name}',
    );
  }

  /// Evaluates and selects the safest discard among candidate cards using
  /// card counting, dead-rank detection, partner synergy, and opponent modeling.
  static game_card.Card _selectBestDiscard({
    required List<game_card.Card> candidates,
    required CardCountingMatrix matrix,
    required List<game_card.Card> board,
    required String nextOpponentId,
    required String partnerId,
    required Map<String, List<String>> skippedMatches,
    required Random random,
  }) {
    if (candidates.length == 1) return candidates.first;

    final opponentSkips = skippedMatches[nextOpponentId] ?? const [];
    final partnerSkips = skippedMatches[partnerId] ?? const [];

    game_card.Card? bestCard;
    double highestScore = -99999.0;

    for (final card in candidates) {
      final rank = card.rank;
      final unseen = matrix.unseen(rank);
      final inHand = matrix.handCounts[rank] ?? 1;

      double score = 0.0;

      // RULE 1: DEAD RANK (ورقة ميتة)
      // 0 unseen cards left in the world: Impossible for opponents to capture!
      if (unseen == 0) {
        score += 1200.0;
      }

      // RULE 2: AVOID KNOWN OPPONENT CARDS
      // If the next opponent skipped this rank previously in Tafweet mode, they hold it!
      final bool nextOpponentHolds = opponentSkips.any((s) => s.startsWith('${rank.name}:'));
      if (nextOpponentHolds) {
        score -= 900.0; // Severe danger penalty
      }

      // RULE 3: PARTNER FEEDING
      // If partner is known to hold this rank, and next opponent doesn't, feeding is rewarded
      final bool partnerHolds = partnerSkips.any((s) => s.startsWith('${rank.name}:'));
      if (partnerHolds && !nextOpponentHolds) {
        score += 450.0;
      }

      // RULE 4: DUPLICATE MANAGEMENT
      // Holding 2+ of the same rank means fewer cards for opponents (unseen <= 2),
      // and if it survives, we can capture on our next turn!
      if (inHand >= 2) {
        score += 250.0;
      }

      // RULE 5: SCARCITY FACTOR
      // Fewer unseen cards means lower probability that opponents hold it
      score += (3 - unseen) * 160.0;

      // RULE 6: BOARD STAKES MULTIPLIER
      // If the board has many cards, danger of throwing an unseen card is magnified
      if (board.isNotEmpty && unseen > 0) {
        final boardDangerMultiplier = 1.0 + (board.length * 0.25);
        if (unseen >= 2) {
          score -= (unseen * 40.0) * boardDangerMultiplier;
        }
      }

      // Small jitter for human-like unpredictability
      score += random.nextDouble() * 12.0;

      if (score > highestScore) {
        highestScore = score;
        bestCard = card;
      }
    }

    return bestCard ?? candidates[random.nextInt(candidates.length)];
  }

  /// Decides a cut point for the deck.
  static int decideCut(int deckCount) {
    if (deckCount <= 6) return 1;
    return 3 + Random().nextInt(deckCount - 6);
  }

  /// Decides whether to vote for shuffle.
  static bool decideShuffleVote(MatchState state, String botId) {
    final currentVotes = state.shuffleVotes;
    final humanVotes = currentVotes.entries
        .where((e) => !e.key.startsWith('bot_'))
        .map((e) => e.value)
        .toList();
    
    if (humanVotes.isEmpty) {
      return Random().nextDouble() < 0.2;
    }
    
    int yesCount = humanVotes.where((v) => v == true).length;
    int noCount = humanVotes.length - yesCount;
    
    if (yesCount > noCount) return true;
    if (noCount > yesCount) return false;
    
    return Random().nextBool();
  }

  /// Decides whether to vote for rematch.
  static bool decideRematchVote() {
    return true; 
  }
}
