import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/game/data/repositories/multiplayer_sync_service.dart';
import 'package:halabessa/features/game/domain/models/room_summary.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/home/presentation/widgets/public_rooms_list.dart';

class LobbyService extends Fake implements MultiplayerSyncService {
  int subscriptions = 0;
  final rooms = StreamController<List<RoomSummary>>();
  @override
  Stream<List<RoomSummary>> watchPublicMatches() {
    subscriptions++;
    return rooms.stream;
  }
}

AppUser profile(String uid, int coins) => AppUser(
  uid: uid,
  email: '',
  displayName: 'Player',
  coins: coins,
  isAdmin: true,
  friends: const ['untrusted'],
);
Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'profile and wallet do not wait for social/admin; lobby stays subscribed',
    () async {
      final profiles = StreamController<AppUser?>();
      final requests = <String, Completer<Map<String, dynamic>>>{};
      final lobby = LobbyService();
      final container = ProviderContainer(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => profiles.stream),
          multiplayerSyncServiceProvider.overrideWithValue(lobby),
          backendCallProvider.overrideWithValue((
            action, {
            data = const {},
            timeout,
          }) {
            return (requests[action] ??= Completer<Map<String, dynamic>>())
                .future;
          }),
        ],
      );
      final subscription = container.listen(currentUserProvider, (_, __) {});
      final roomSubscription = container.listen(
        publicRoomsProvider,
        (_, __) {},
      );
      profiles.add(profile('A', 100));
      await flush();
      expect(container.read(currentUserProvider)!.coins, 100);
      expect(container.read(currentUserProvider)!.isAdmin, false);
      expect(container.read(currentUserProvider)!.friends, isEmpty);
      for (var i = 0; i < 10; i++) {
        profiles.add(profile('A', 101 + i));
      }
      await flush();
      expect(container.read(currentUserProvider)!.coins, 110);
      expect(
        requests.keys,
        unorderedEquals(['getSocialGraph', 'getAdminStatus']),
      );
      expect(lobby.subscriptions, 1);
      requests['getSocialGraph']!.complete({
        'friends': ['verified'],
      });
      requests['getAdminStatus']!.complete({'admin': true});
      await flush();
      expect(container.read(currentUserProvider)!.friends, ['verified']);
      expect(container.read(currentUserProvider)!.isAdmin, true);
      expect(lobby.subscriptions, 1);
      requests['getSocialGraph'] = Completer<Map<String, dynamic>>();
      container.invalidate(socialGraphProvider);
      await flush();
      expect(container.read(currentUserProvider)!.friends, ['verified']);
      profiles.add(profile('A', 111));
      await flush();
      expect(container.read(currentUserProvider)!.coins, 111);
      expect(lobby.subscriptions, 1);
      requests['getSocialGraph']!.complete({
        'friends': ['refreshed'],
      });
      await flush();
      expect(container.read(currentUserProvider)!.friends, ['refreshed']);
      subscription.close();
      roomSubscription.close();
      container.dispose();
      await profiles.close();
      await lobby.rooms.close();
    },
  );

  test(
    'account switch/logout ignores late enrichment and clears privilege',
    () async {
      final profiles = StreamController<AppUser?>();
      final requests = <String, List<Completer<Map<String, dynamic>>>>{};
      final container = ProviderContainer(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => profiles.stream),
          backendCallProvider.overrideWithValue((
            action, {
            data = const {},
            timeout,
          }) {
            final next = Completer<Map<String, dynamic>>();
            (requests[action] ??= []).add(next);
            return next.future;
          }),
        ],
      );
      final subscription = container.listen(currentUserProvider, (_, __) {});
      profiles.add(profile('A', 1));
      await flush();
      requests['getAdminStatus']!.first.complete({'admin': true});
      requests['getSocialGraph']!.first.complete({
        'friends': ['A-friend'],
      });
      await flush();
      profiles.add(profile('B', 2));
      await flush();
      expect(container.read(currentUserProvider)!.uid, 'B');
      expect(container.read(currentUserProvider)!.isAdmin, false);
      expect(container.read(currentUserProvider)!.friends, isEmpty);
      profiles.add(null);
      await flush();
      requests['getAdminStatus']!.last.complete({'admin': true});
      requests['getSocialGraph']!.last.complete({
        'friends': ['B-friend'],
      });
      await flush();
      expect(container.read(currentUserProvider), isNull);
      subscription.close();
      container.dispose();
      await profiles.close();
    },
  );
}
