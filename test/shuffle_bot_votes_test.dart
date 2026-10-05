import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/shuffle_bot_votes.dart';

void main() {
  const ids = ['a', 'b', 'c', 'bot_4'];
  test('shuffle bots follow human majority, not old bot ballots', () {
    expect(resolveShuffleBotVotes(ids, {'a': true, 'b': true, 'c': false, 'bot_4': false})['bot_4'], true);
    expect(resolveShuffleBotVotes(ids, {'a': true, 'b': false, 'c': false})['bot_4'], false);
    expect(resolveShuffleBotVotes(['a', 'bot_2'], {})['bot_2'], false);
  });
  test('ties randomly choose a shared bot ballot', () {
    final outcomes = <bool>{};
    for (var seed = 0; seed < 40; seed++) {
      final votes = resolveShuffleBotVotes(['a', 'b', 'bot_3', 'bot_4'], {'a': true, 'b': false}, random: Random(seed));
      expect(votes['bot_3'], votes['bot_4']);
      outcomes.add(votes['bot_3']!);
    }
    expect(outcomes, {true, false});
  });
}
