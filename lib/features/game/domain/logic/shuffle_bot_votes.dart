import 'dart:math';

/// Called only after all human ballots (including timeout No) are final.
Map<String, bool> resolveShuffleBotVotes(
  List<String> playerIds,
  Map<String, bool> humanVotes, {
  Random? random,
}) {
  final humans = playerIds.where((id) => !id.startsWith('bot_') && !id.startsWith('waiting_'));
  final votes = <String, bool>{for (final id in humans) id: humanVotes[id] ?? false};
  final yes = votes.values.where((vote) => vote).length;
  final no = votes.length - yes;
  final bots = playerIds.where((id) => id.startsWith('bot_')).toList();
  if (bots.isEmpty) return votes;
  final choice = votes.isEmpty ? false : yes == no ? (random ?? Random()).nextBool() : yes > no;
  for (final id in bots) { votes[id] = choice; }
  return votes;
}
