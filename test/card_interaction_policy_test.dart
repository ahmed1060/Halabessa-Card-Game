import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/presentation/providers/card_interaction_policy.dart';

MatchState room(String id, {int protocol = 1, bool closed = false}) =>
    MatchState(
      id: id,
      mode: GameMode.classic,
      dealerIndex: 0,
      currentTurnIndex: 0,
      protocolVersion: protocol,
      roomClosed: closed,
      playerIds: const ['a', 'b', 'c', 'd'],
    );

void main() {
  test(
    'production policy follows explicit build controls, never a query parameter',
    () {
      expect(
        cardInteractionsEnabled,
        const bool.fromEnvironment('HALABESSA_CARD_INTERACTIONS'),
      );
      expect(
        onlineCardInteractionsEnabled,
        const bool.fromEnvironment('HALABESSA_ONLINE_CARD_INTERACTIONS'),
      );
      expect(
        cardInteractionsFor(room('ABC12345')),
        cardInteractionsEnabled && onlineCardInteractionsEnabled,
      );
      expect(
        cardInteractionsFor(room('OFFLINE_practice', protocol: 0)),
        cardInteractionsEnabled,
      );
    },
  );

  test(
    'online rollout requires server authority and can roll back independently',
    () {
      final online = room('ABC12345');
      final practice = room('OFFLINE_practice', protocol: 0);
      expect(
        cardInteractionsFor(online, enabled: true, onlineEnabled: true),
        isTrue,
      );
      expect(
        cardInteractionsFor(practice, enabled: true, onlineEnabled: false),
        isTrue,
      );
      expect(
        cardInteractionsFor(online, enabled: true, onlineEnabled: false),
        isFalse,
      );
      expect(
        cardInteractionsFor(online, enabled: false, onlineEnabled: true),
        isFalse,
      );
      expect(
        cardInteractionsFor(practice, enabled: false, onlineEnabled: true),
        isFalse,
      );
      expect(
        cardInteractionsFor(
          room('ABC12345', protocol: 0),
          enabled: true,
          onlineEnabled: true,
        ),
        isFalse,
      );
      expect(
        cardInteractionsFor(
          room('ABC12345', closed: true),
          enabled: true,
          onlineEnabled: true,
        ),
        isFalse,
      );
    },
  );

  test(
    'both online and practice preserve renderer negotiation and spectator safety',
    () {
      for (final state in [
        room('ABC12345'),
        room('OFFLINE_local', protocol: 0),
      ]) {
        bool input({
          bool spectator = false,
          bool unity = false,
          bool interactions = false,
          bool refined = false,
          bool actions = false,
        }) => cardInteractionInputFor(
          state,
          spectator: spectator,
          unityHand: unity,
          unityInteractionsReady: interactions,
          unityRefinementsReady: refined,
          visualActionsReady: actions,
          refinedHand: true,
          enabled: true,
          onlineEnabled: true,
        );
        expect(
          input(),
          isTrue,
          reason: 'Flutter works without a Unity handshake',
        );
        expect(input(spectator: true), isFalse);
        expect(input(unity: true), isFalse);
        expect(
          input(unity: true, interactions: true, actions: true),
          isFalse,
          reason:
              'old exports cannot handle refined same-card public placement',
        );
        expect(input(unity: true, interactions: true, refined: true), isFalse);
        expect(
          input(unity: true, interactions: true, refined: true, actions: true),
          isTrue,
        );
        expect(
          input(
            spectator: true,
            unity: true,
            interactions: true,
            refined: true,
            actions: true,
          ),
          isFalse,
        );
      }
    },
  );
}
