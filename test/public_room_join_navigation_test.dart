import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/game/data/repositories/multiplayer_sync_service.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/models/room_summary.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/home/presentation/widgets/public_rooms_list.dart';

class LobbyService implements MultiplayerSyncService {
  final Stream<List<RoomSummary>> rooms;
  LobbyService(this.rooms);
  @override
  Stream<List<RoomSummary>> watchPublicMatches() => rooms;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class JoiningNotifier extends MatchStateNotifier {
  final Completer<void> pending;
  JoiningNotifier(super.ref, this.pending);
  @override
  Future<void> joinMatch(String id, String uid, String name) => pending.future;
}

void main() {
  testWidgets('successful join navigates even after its lobby tile disappears', (tester) async {
    final rooms = StreamController<List<RoomSummary>>();
    addTearDown(rooms.close);
    final pending = Completer<void>();
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserProvider.overrideWithValue(AppUser(uid: 'qa', email: '', displayName: 'QA')),
      multiplayerSyncServiceProvider.overrideWithValue(LobbyService(rooms.stream)),
      matchStateProvider.overrideWith((ref) => JoiningNotifier(ref, pending)),
    ], child: MaterialApp(routes: {'/game': (_) => const Scaffold(body: Text('Joined game'))},
      home: const Scaffold(body: PublicRoomsList()))));
    rooms.add([RoomSummary(id: 'ABC12345', mode: GameMode.classic,
      playerIds: ['qa_old', 'waiting_1', 'waiting_2', 'waiting_3'],
      isPublic: true, phase: GamePhase.waitingForPlayers)]);
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    rooms.add([]);
    await tester.pump();
    expect(find.byType(ElevatedButton), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Joined game'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
