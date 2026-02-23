enum Suit { hearts, diamonds, clubs, spades }

enum Rank {
  two(2), three(3), four(4), five(5), six(6), seven(7), eight(8),
  nine(9), ten(10), jack(11), queen(12), king(13), ace(14); // Ace is high in comparison, or 1 in scoring

  final int value;
  const Rank(this.value);
}

class Card {
  final Suit suit;
  final Rank rank;

  const Card(this.suit, this.rank);

  bool get isJack => rank == Rank.jack;
  bool get isDiamondSeven => suit == Suit.diamonds && rank == Rank.seven; // "Al Koomi" or special cards
  
  // Basra value evaluation
  int get basraValue {
    switch (rank) {
      case Rank.ace: return 1;
      case Rank.two: return 2;
      case Rank.three: return 3;
      case Rank.four: return 4;
      case Rank.five: return 5;
      case Rank.six: return 6;
      case Rank.seven: return 7;
      case Rank.eight: return 8;
      case Rank.nine: return 9;
      case Rank.ten: return 10;
      default: return 0; // Face cards don't have numerical sum value for capturing by sum, they capture by matching
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Card &&
          runtimeType == other.runtimeType &&
          suit == other.suit &&
          rank == other.rank;

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;

  @override
  String toString() {
    return '\${rank.name} of \${suit.name}';
  }

  Map<String, dynamic> toJson() => {
        'suit': suit.name,
        'rank': rank.name,
      };

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(
      Suit.values.byName(json['suit'] as String),
      Rank.values.byName(json['rank'] as String),
    );
  }
}
