enum BotDifficulty { easy, medium, hard, expert }

BotDifficulty parseBotDifficulty(String? value) =>
    BotDifficulty.values.firstWhere(
      (difficulty) => difficulty.name == value,
      orElse: () => BotDifficulty.medium,
    );
