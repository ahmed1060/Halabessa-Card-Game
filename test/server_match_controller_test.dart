import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/services/supabase_backend_service.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/game/data/repositories/multiplayer_sync_service.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as cards;
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';

class FakeSync implements MultiplayerSyncService {
  final leaves = <Completer<void>>[];
  int presenceRemovals = 0;
  @override
  Future<void> leaveServerMatch(MatchState matchState, String callerUid) {
    final request = Completer<void>();
    leaves.add(request);
    return request.future;
  }
  @override
  Future<void> removePresence(String matchId, String playerId) async {
    presenceRemovals++;
  }
  final types = <String>[];
  final versions = <int>[];
  final pending = <Completer<MatchState>>[];
  @override
  Future<MatchState> submitMatchCommand({required MatchState matchState,
    required String commandType, required String callerUid,
    Map<String, dynamic> payload = const {}, String? actorUid, String? commandId}) {
    types.add(commandType);
    versions.add(matchState.serverVersion);
    final request = Completer<MatchState>();
    pending.add(request);
    return request.future;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Legacy call: ${invocation.memberName}');
}

void main() {
  final match = MatchState.fromJson({'id': 'ROOM1234', 'mode': 'classic',
    'protocolVersion': 1, 'serverVersion': 3, 'phase': 'playing',
    'playerIds': ['human', 'bot_1', 'bot_2', 'bot_3'], 'currentTurnIndex': 0,
    'handCards': {'human': [{'suit': 'hearts', 'rank': 'ace'}]},
    'handCounts': {'human': 1, 'bot_1': 4, 'bot_2': 4, 'bot_3': 4}});
  late ProviderContainer container;
  late FakeSync sync;
  late MatchStateNotifier notifier;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sync = FakeSync();
    container = ProviderContainer(overrides: [
      multiplayerSyncServiceProvider.overrideWithValue(sync),
      currentUserProvider.overrideWithValue(AppUser(uid: 'human', email: '', displayName: 'QA')),
    ]);
    notifier = container.read(matchStateProvider.notifier);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifier.state = match;
    notifier.lastBoundMatchId = match.id;
  });
  tearDown(() => container.dispose());

  test('play submits intent only, with no optimistic hand removal or duplicate', () async {
    final card = match.handCards['human']!.single;
    final play = notifier.playCard('human', card);
    await notifier.playCard('human', card);
    expect(sync.types, ['playCard']);
    expect(container.read(matchStateProvider), same(match));
    sync.pending.single.complete(match.copyWith(serverVersion: 4, handCards: {'human': []}));
    await play;
    expect(container.read(matchStateProvider)!.serverVersion, 4);
    expect(container.read(matchStateProvider)!.handCards['human'], isEmpty);
  });
  test('a queued human vote uses latest accepted version rather than disappearing', () async {
    final first = notifier.voteShuffle('human', true);
    final second = notifier.voteRematch('human', true);
    expect(sync.types, ['voteShuffle']);
    sync.pending.first.complete(match.copyWith(serverVersion: 4));
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(sync.types, ['voteShuffle', 'voteRematch']);
    expect(sync.versions, [3, 4]);
    sync.pending.last.complete(match.copyWith(serverVersion: 5));
    await second;
  });
  test('version conflict adopts current server state without replaying card', () async {
    final play = notifier.playCard('human', match.handCards['human']!.single);
    sync.pending.single.completeError(SupabaseBackendException('version_conflict', details: {
      'state': match.copyWith(serverVersion: 4).toJson(),
      'hand': match.handCards['human']!.map((c) => c.toJson()).toList(),
    }));
    await play;
    expect(container.read(matchStateProvider)!.serverVersion, 4);
    expect(sync.types, ['playCard']);
    expect(container.read(matchFeedbackProvider)?.translationKey, 'match_action_changed');
  });
  test('rejected human intent surfaces safe feedback without changing cards', () async {
    final play = notifier.playCard('human', match.handCards['human']!.single);
    sync.pending.single.completeError(const SupabaseBackendException('phase_not_ready'));
    await play;
    expect(container.read(matchStateProvider), same(match));
    expect(container.read(matchFeedbackProvider)?.translationKey, 'match_action_rejected');
  });
  test('ambiguous network failure does not remove the card or claim rejection', () async {
    final play = notifier.playCard('human', match.handCards['human']!.single);
    sync.pending.single.completeError(StateError('transport unavailable'));
    await play;
    expect(container.read(matchStateProvider), same(match));
    expect(container.read(matchFeedbackProvider)?.translationKey, 'match_action_unavailable');
  });
  test('backend failure does not present an ambiguous play as definitely rejected', () async {
    final play = notifier.playCard('human', match.handCards['human']!.single);
    sync.pending.single.completeError(const SupabaseBackendException('internal_error'));
    await play;
    expect(container.read(matchStateProvider), same(match));
    expect(container.read(matchFeedbackProvider)?.translationKey, 'match_action_unavailable');
  });
  test('failed leave retains the room and allows a later retry', () async {
    final leave = notifier.leaveMatch();
    expect(await notifier.leaveMatch(), isFalse);
    expect(sync.leaves, hasLength(1));
    sync.leaves.single.completeError(StateError('transport unavailable'));
    expect(await leave, isFalse);
    expect(container.read(matchStateProvider), same(match));
    expect(sync.presenceRemovals, 0);
    expect(container.read(matchFeedbackProvider)?.translationKey, 'match_leave_failed');
    final retry = notifier.leaveMatch();
    sync.leaves.last.complete();
    expect(await retry, isTrue);
    expect(container.read(matchStateProvider), isNull);
    expect(sync.presenceRemovals, 1);
  });
  test('confirmed leave waits for acknowledgement before clearing local state', () async {
    final leave = notifier.leaveMatch();
    expect(container.read(matchStateProvider), same(match));
    sync.leaves.single.complete();
    expect(await leave, isTrue);
    expect(container.read(matchStateProvider), isNull);
  });
  test('server removal notification arriving before leave response still permits exit', () async {
    final leave = notifier.leaveMatch();
    expect(await notifier.leaveMatch(notifyServer: false), isTrue);
    sync.leaves.single.complete();
    expect(await leave, isTrue);
    expect(sync.leaves, hasLength(1));
  });
  test('confirmed removal notification takes precedence over a lost leave response', () async {
    final leave = notifier.leaveMatch();
    await notifier.leaveMatch(notifyServer: false);
    sync.leaves.single.completeError(StateError('response lost'));
    expect(await leave, isTrue);
    expect(container.read(matchFeedbackProvider), isNull);
  });
  test('late leave acknowledgement cannot clear a newly bound room', () async {
    final leave = notifier.leaveMatch();
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifier.state = null;
    notifier.bindToMatch('OFFLINE_NEW');
    final next = match.copyWith(id: 'OFFLINE_NEW');
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifier.state = next;
    sync.leaves.single.complete();
    expect(await leave, isFalse);
    expect(container.read(matchStateProvider), same(next));
  });
  test('late accepted play cannot overwrite a newer notification', () async {
    final play = notifier.playCard('human', match.handCards['human']!.single);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifier.state = match.copyWith(serverVersion: 6);
    sync.pending.single.complete(match.copyWith(serverVersion: 4));
    await play;
    expect(container.read(matchStateProvider)!.serverVersion, 6);
  });
  test('another player cannot be used as the command actor', () async {
    await notifier.playCard('bot_1', cards.Card.fromJson({'suit': 'hearts', 'rank': 'ace'}));
    expect(sync.types, isEmpty);
  });
}
