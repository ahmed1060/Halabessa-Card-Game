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

}
