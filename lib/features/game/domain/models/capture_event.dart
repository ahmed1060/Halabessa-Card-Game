import 'card.dart';

/// Accepted public cards only. This never contains an opponent's private hand.
class CaptureEvent {
  final String id;
  final String team;
  final String playerUid;
  final DateTime createdAt;
  final List<Card> cards;
  const CaptureEvent({required this.id, required this.team,
    required this.playerUid, required this.createdAt, required this.cards});

  Map<String, dynamic> toJson() => {'id': id, 'team': team,
    'playerUid': playerUid, 'createdAt': createdAt.toIso8601String(),
    'cards': cards.map((card) => card.toJson()).toList()};

  static List<CaptureEvent> parse(dynamic raw) {
    final values = raw is List ? raw : raw is Map ? raw.values.toList() : const [];
    final result = <CaptureEvent>[];
    for (final value in values.take(52)) {
      if (value is! Map || value['id'] is! String ||
          !const ['teamA', 'teamB'].contains(value['team'])) continue;
      final date = DateTime.tryParse('${value['createdAt']}');
      final rawCards = value['cards'];
      final cards = rawCards is List ? rawCards : rawCards is Map ? rawCards.values.toList() : const [];
      if (date == null || cards.isEmpty || cards.length > 52) continue;
      try {
        result.add(CaptureEvent(id: value['id'], team: value['team'],
          playerUid: '${value['playerUid'] ?? ''}', createdAt: date,
          cards: List.unmodifiable(cards.whereType<Map>().map((card) =>
            Card.fromJson(Map<String, dynamic>.from(card))))));
      } catch (_) { /* Invalid presentation data cannot break gameplay. */ }
    }
    return List.unmodifiable(result);
  }
}
