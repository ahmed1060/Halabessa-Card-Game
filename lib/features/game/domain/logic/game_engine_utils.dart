import '../models/card.dart' as game_card;

class GameEngineUtils {
  
  /// Determines if a played card captures anything from the board.
  /// Returns a list of captured cards (including the played card) if successful,
  /// or an empty list if nothing is captured.
  static List<game_card.Card> calculateCapture(game_card.Card playedCard, List<game_card.Card> board) {
    if (board.isEmpty) return [];

    // Halabessa Core Rule: Capture only occurs if played card matches the CURRENT TOP card of the board.
    final topCard = board.last;
    
    if (playedCard.rank == topCard.rank) {
      // In Halabessa, a top-match sweeps the ENTIRE board.
      final captured = List<game_card.Card>.from(board);
      captured.add(playedCard);
      return captured;
    }

    return [];
  }
  
  // Internal sum finder removed as it is not part of Halabessa rules

  /// Check if the capture constitutes a "Basra" (Clear board)
  static bool isBasra(game_card.Card playedCard, List<game_card.Card> capturedCards, List<game_card.Card> boardBeforeCapture) {
     if (capturedCards.isEmpty) return false;
     
     // Note: capturedCards includes the playedCard
     // If the number of captured cards from the board equals the board size, it's a sweep.
     bool clearedBoard = (capturedCards.length - 1) == boardBeforeCapture.length;
     
     if (clearedBoard && boardBeforeCapture.isNotEmpty) {
       // Jack sweeping the board is NOT a Basra unless the board itself was empty/jack
       if (playedCard.isJack && boardBeforeCapture.every((c) => !c.isJack)) {
         return false; 
       }
       // 7 Diamond sweeping board is NOT a Basra natively
       if (playedCard.isDiamondSeven && boardBeforeCapture.every((c) => !c.isDiamondSeven)) {
         return false;
       }
       return true;
     }
     return false;
  }
}
