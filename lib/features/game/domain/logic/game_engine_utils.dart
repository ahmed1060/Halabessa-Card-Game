import '../models/card.dart' as game_card;

class GameEngineUtils {
  
  /// Determines if a played card captures anything from the board.
  /// Returns a list of captured cards (including the played card) if successful,
  /// or an empty list if nothing is captured.
  static List<game_card.Card> calculateCapture(game_card.Card playedCard, List<game_card.Card> board) {
    if (board.isEmpty) return [];

    final captured = <game_card.Card>[];
    
    // 1. Check for exact Rank matches (Standard Capture & Basra)
    final exactMatches = board.where((card) => card.rank == playedCard.rank).toList();
    if (exactMatches.isNotEmpty) {
      // Typically, capturing one exact match (or all if applying standard Egyptian rules)
      // For 7alabessa, generally we capture ALL matching ranks if multiple exist on board.
      captured.addAll(exactMatches);
    }
    
    // 2. Check for Boy (Jack) sweep rule
    if (playedCard.isJack) {
       // Jack captures everything on the board
       captured.addAll(board);
       // Remove exact matches to avoid duplicates
       captured.removeWhere((c) => exactMatches.contains(c));
    }
    
    // 3. Check for 7 of Diamonds (Al Koomi) sweep rule
    if (playedCard.isDiamondSeven) {
       // Koomi captures everything on the board
       captured.addAll(board);
       captured.removeWhere((c) => exactMatches.contains(c));
    }

    // 4. Sum Captures (only if the card is numerical: Ace to 10)
    if (!playedCard.isJack && !playedCard.isDiamondSeven && playedCard.basraValue > 0) {
      final targetSum = playedCard.basraValue;
      
      // Basic recursive or combinatorial sum finder for cards on board
      // Here we will implement a simple iteration for combinations up to 2-3 boards 
      // (Full standard game requires subset sum, we use a basic subset generator)
      List<List<game_card.Card>> validSums = _findSubsetsWithSum(board, targetSum);
      
      for (var subset in validSums) {
        for (var card in subset) {
          if (!captured.contains(card)) {
            captured.add(card);
          }
        }
      }
    }

    if (captured.isNotEmpty) {
      captured.add(playedCard);
    }

    return captured;
  }
  
  /// Helper to find combinations of cards that equal a sum target
  static List<List<game_card.Card>> _findSubsetsWithSum(List<game_card.Card> board, int target) {
    List<List<game_card.Card>> results = [];
    int n = board.length;
    // Iterate through all possible subsets (2^n)
    for (int i = 1; i < (1 << n); i++) {
      List<game_card.Card> currentSubset = [];
      int currentSum = 0;
      for (int j = 0; j < n; j++) {
        if ((i & (1 << j)) != 0) {
          // only add numerical cards to sum calculations
          int val = board[j].basraValue;
          if (val > 0) {
             currentSum += val;
             currentSubset.add(board[j]);
          } else {
             currentSum = -999; // Invalidate if containing non-numerical cards
          }
        }
      }
      if (currentSum == target && currentSubset.length > 1) {
        results.add(currentSubset);
      }
    }
    return results;
  }

  /// Check if the capture constitutes a "Basra" (Clear board)
  static bool isBasra(game_card.Card playedCard, List<game_card.Card> capturedCards, List<game_card.Card> boardBeforeCapture) {
     if (capturedCards.isEmpty) return false;
     
     // Note: capturedCards includes the playedCard
     // If the number of captured cards from the board equals the board size, it's a sweep.
     bool clearedBoard = (capturedCards.length - 1) == boardBeforeCapture.length;
     
     if (clearedBoard && boardBeforeCapture.isNotEmpty) {
       // Jack sweeping the board is NOT a Basra unless the board itself was empty/jack
       // In Halabessa, standard rules usually dictate Jacks don't score "Basra" points, just capture.
       if (playedCard.isJack && boardBeforeCapture.every((c) => !c.isJack)) {
         return false; 
       }
       // 7 Diamond sweeping board is NOT a Basra natively unless checking specific game variations
       if (playedCard.isDiamondSeven && boardBeforeCapture.every((c) => !c.isDiamondSeven)) {
         return false;
       }
       return true;
     }
     return false;
  }

  /// Complete scoring matrix calculation based on the established 7alabessa rules.
  static int calculatePoints({
    required game_card.Card playedCard,
    required List<game_card.Card> capturedCards,
    required List<game_card.Card> boardBeforeCapture,
    required bool isTafweetMode,
    required bool isFirstMoveOfRound,
    required bool isConsecutiveTafweet,
  }) {
    if (capturedCards.isEmpty) return 0;
    
    int points = 0;
    bool basra = isBasra(playedCard, capturedCards, boardBeforeCapture);
    
    if (basra) {
       points += 1; // Base Basra point
       
       if (isTafweetMode) {
          if (isFirstMoveOfRound) {
             points += 20; // Fasha Tafweet
          } else if (isConsecutiveTafweet) {
             points += 30; // Double Tafweet
          } else {
             points += 10; // Standard Tafweet
          }
       }
    }
    
    return points;
  }
}
