import 'card.dart' as game_card;

abstract class GameAction {
  final String playerId;
  final DateTime timestamp;

  GameAction(this.playerId) : timestamp = DateTime.now();
}

class PlayCardAction extends GameAction {
  final game_card.Card card;
  PlayCardAction(String playerId, this.card) : super(playerId);
}

class CutAction extends GameAction {
  final int cutIndex;
  CutAction(String playerId, this.cutIndex) : super(playerId);
}

class DealAction extends GameAction {
  final bool isInitial;
  DealAction(String playerId, {this.isInitial = false}) : super(playerId);
}

class VoteAction extends GameAction {
  final bool vote;
  final bool isRematch; // true for rematch, false for shuffle
  VoteAction(String playerId, this.vote, {this.isRematch = false}) : super(playerId);
}
