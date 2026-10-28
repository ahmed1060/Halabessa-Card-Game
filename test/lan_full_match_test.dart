import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/domain/logic/game_engine.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/domain/models/card_feature_state.dart';
import 'package:halabessa/features/game/domain/models/game_action.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/lan/data/lan_connection.dart';
import 'package:halabessa/features/lan/data/lan_socket_transport.dart';
import 'package:halabessa/features/lan/presentation/lan_match_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoopbackHttp extends HttpOverrides {}

Future<void> _until(bool Function() ready, {int seconds = 20}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) fail('LAN transition timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// Slow by design: real host timers, engine, TLS sockets and client commands.
/// No Flutter widget clock or fabricated authoritative snapshot is used.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final priorHttp = HttpOverrides.current;
  setUpAll(() => HttpOverrides.global = _LoopbackHttp());
  tearDownAll(() => HttpOverrides.global = priorHttp);

  for (final scenario in [
    (GameMode.classic, 4, false),
    (GameMode.tafweet, 4, false),
    (GameMode.classic, 2, true),
  ]) {
    final (mode, humanCount, deckOnly) = scenario;
    test(
      'complete ${mode.name} LAN ${deckOnly ? 'bot-filled deck' : 'match'} over pinned TLS',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final driver = LanMatchDriver(
          preferences,
          AppUser(uid: 'LOCAL_profile', email: '', displayName: 'Host'),
        );
        final host = await hostLanRoom(
          driver,
          'Host',
          loopbackForTesting: true,
        );
        final peers = <LanConnection>[];
        StreamSubscription<MatchState>? observation;
        addTearDown(() async {
          await observation?.cancel();
          for (final peer in peers) {
            await peer.close(leave: false);
            peer.dispose();
          }
          await host.close();
        });
        for (final name in ['Second', 'Third', 'Fourth'].take(humanCount - 1)) {
          peers.add(
            await joinLanRoom(
              host.invitation('127.0.0.1'),
              name,
              loopbackForTesting: true,
            ),
          );
        }
        final clients = [host.local, ...peers];
        final byUid = {for (final client in clients) client.uid: client};
        Future<bool> command(
          LanConnection client,
          String action,
          Map<String, dynamic> payload,
        ) async {
          final revision = host.local.snapshot!['revision'] as int;
          await _until(
            () => (client.snapshot?['revision'] as int? ?? -1) >= revision,
          );
          return client.command(action, payload);
        }

        final scored = <int>{};
        final dealtHands = <int, Set<int>>{};
        final played = <int, Set<String>>{};
        final commits = <MatchState>[];
        MatchState? previous;
        observation = driver.changes.listen((state) {
          commits.add(state);
          expect(state.earnedCoins, isEmpty);
          expect(state.earnedStars, isEmpty);
          expect(state.usesServerCommands, isFalse);
          if (state.phase == GamePhase.playing ||
              state.phase == GamePhase.roundScoring) {
            final known = <game.Card>[
              ...state.board,
              for (final hand in state.handCards.values) ...hand,
              for (final stack in state.harvestStacks.values)
                for (final capture in stack) ...[
                  capture.leadingCard,
                  ...capture.capturedCards,
                ],
            ];
            expect(known.length + state.deckCount, 52);
            expect(
              known.map((c) => c.firebaseKey).toSet().length,
              known.length,
            );
          }
          if (state.phase == GamePhase.playing && !state.areAllHandsEmpty) {
            dealtHands
                .putIfAbsent(state.roundCount, () => {})
                .add(state.handInRound);
          }
          final before = previous;
          if (before != null && before.roundCount == state.roundCount) {
            final after = state.handCards.values.expand((h) => h).toSet();
            final removed = before.handCards.values
                .expand((h) => h)
                .where((card) => !after.contains(card));
            for (final card in removed) {
              expect(
                played
                    .putIfAbsent(state.roundCount, () => {})
                    .add(card.firebaseKey),
                isTrue,
                reason: 'A card played twice',
              );
            }
          }
          if (state.phase == GamePhase.roundScoring &&
              scored.add(state.roundCount)) {
            expect(played[state.roundCount], hasLength(48));
            expect(dealtHands[state.roundCount], {1, 2, 3});
            // Safe summaries only: never log invitation/resume credentials.
            // ignore: avoid_print
            print(
              '${mode.name}: deck ${state.roundCount} complete; '
              '48 plays, 52 unique cards, ${state.teamAScore}:${state.teamBScore}',
            );
          }
          previous = state;
        });
        await host.start(mode: mode.name);
        await _until(() => driver.state?.phase == GamePhase.preRoundCut);
        var resumed = false;
        final exercised = <int>{};
        final voted = <String>{};
        final deadline = DateTime.now().add(const Duration(minutes: 12));
        while (deckOnly
            ? scored.isEmpty
            : driver.state?.phase != GamePhase.rematchVoting) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Full match did not finish');
          }
          final state = driver.state!;
          // Wait for the same current revision on each real remote viewer.
          final revision = host.local.snapshot!['revision'] as int;
          await _until(
            () => clients.every(
              (c) => (c.snapshot?['revision'] as int? ?? -1) >= revision,
            ),
          );
          for (final client in clients) {
            final view = client.snapshot!['match'] as Map;
            expect((view['handCards'] as Map).keys, [client.uid]);
            expect(view['earnedCoins'], isEmpty);
            expect(view['earnedStars'], isEmpty);
          }
          if (state.phase == GamePhase.preRoundCut) {
            final dealer = byUid[state.playerIds[state.dealerIndex]];
            if (dealer != null) {
              expect(await command(dealer, 'cut', {'position': 20}), isTrue);
            }
          } else if (state.phase == GamePhase.shuffleVoting) {
            for (final client in clients) {
              final key = '${state.roundCount}:${client.uid}';
              if (voted.add(key)) {
                expect(
                  await command(client, 'voteShuffle', {'vote': true}),
                  isTrue,
                );
              }
            }
          } else if (state.phase == GamePhase.playing &&
              !state.areAllHandsEmpty) {
            if (state.handInRound == 1 && exercised.add(state.roundCount)) {
              // Every player's allowances reset per full deck, not per hand.
              for (final client in clients) {
                final hand = driver.state!.handCards[client.uid]!;
                expect(
                  CardFeatureState(driver.state!).remaining(client.uid),
                  3,
                );
                expect(
                  CardFeatureState(
                    driver.state!,
                  ).remaining(client.uid, slam: true),
                  3,
                );
                for (final card in hand.take(3)) {
                  expect(
                    await command(client, 'show', {'card': card.toJson()}),
                    isTrue,
                  );
                }
                final before = driver.state!;
                expect(
                  await command(client, 'show', {'card': hand.last.toJson()}),
                  isFalse,
                );
                expect(driver.state!.handCards, before.handCards);
                expect(
                  CardFeatureState(driver.state!).remaining(client.uid),
                  0,
                );
              }
              if (!resumed) {
                final client = peers.last;
                final uid = client.uid;
                await client.suspend();
                await _until(
                  () => driver.state!.playerOnlineStatus[uid] == false,
                );
                await client.reconnect();
                expect(client.uid, uid);
                expect(driver.state!.playerOnlineStatus[uid], isTrue);
                expect(CardFeatureState(driver.state!).remaining(uid), 0);
                resumed = true;
              }
            }
            final current = driver.state!;
            if (current.phase != GamePhase.playing ||
                current.areAllHandsEmpty) {
              continue;
            }
            final uid = current.playerIds[current.currentTurnIndex];
            if (!byUid.containsKey(uid)) {
              // Only the real host tick drives bots; a peer never impersonates one.
              await Future<void>.delayed(const Duration(milliseconds: 100));
              continue;
            }
            if ((current.handCards[uid]?.length ?? 0) <= 1) {
              // The existing host last-card auto-play remains enabled.
              await Future<void>.delayed(const Duration(milliseconds: 100));
              continue;
            }
            final card = current.handCards[uid]!.first;
            final client = byUid[uid]!;
            final remaining = CardFeatureState(
              current,
            ).remaining(uid, slam: true);
            final expected = GameEngine.apply(
              current,
              PlayCardAction(uid, card),
            ).newState;
            final firstCommit = commits.length;
            if (remaining == 0) {
              expect(
                await command(client, 'play', {
                  'card': card.toJson(),
                  'slam': true,
                }),
                isFalse,
              );
              expect(driver.state!.handCards, current.handCards);
            }
            expect(
              await command(client, 'play', {
                'card': card.toJson(),
                'slam': remaining > 0,
              }),
              isTrue,
            );
            final accepted = commits
                .skip(firstCommit)
                .firstWhere(
                  (s) =>
                      s.phase == GamePhase.playing &&
                      s.currentTurnIndex == expected.currentTurnIndex &&
                      s.handCards[uid]?.length ==
                          expected.handCards[uid]?.length,
                );
            expect(accepted.board, expected.board);
            expect(accepted.handCards, expected.handCards);
            expect(accepted.currentTurnIndex, expected.currentTurnIndex);
            expect(accepted.teamAScore, expected.teamAScore);
            expect(accepted.teamBScore, expected.teamBScore);
            expect(
              CardFeatureState(accepted).remaining(uid, slam: true),
              remaining > 0 ? remaining - 1 : 0,
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 160));
        }
        expect(scored, isNotEmpty);
        expect(resumed, isTrue);
        if (deckOnly) {
          expect(
            driver.state!.playerIds.where((id) => id.startsWith('bot_')),
            hasLength(2),
          );
          expect(Firebase.apps, isEmpty);
          return;
        }
        expect(
          driver.state!.teamAScore >= 41 || driver.state!.teamBScore >= 41,
          isTrue,
        );
        expect(Firebase.apps, isEmpty);
        // Declining a rematch must close only this local match, never mint rewards.
        for (final client in clients) {
          final revision = host.local.snapshot!['revision'] as int;
          await _until(
            () => (client.snapshot?['revision'] as int? ?? -1) >= revision,
          );
          if (driver.state!.phase != GamePhase.rematchVoting) break;
          expect(await command(client, 'voteRematch', {'vote': false}), isTrue);
        }
        await _until(() => driver.state?.phase == GamePhase.matchOver);
        expect(driver.state!.earnedCoins, isEmpty);
        expect(driver.state!.earnedStars, isEmpty);
        expect(Firebase.apps, isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 15)),
      skip: !const bool.fromEnvironment('HALABESSA_LAN_FULL_MATCH_QA'),
    );
  }
}
