// Opt-in, deterministic visual comparison of the actual game screen. Never
// mounted by main.dart; fixtures cannot enter online/practice production state.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as cards;
import 'package:halabessa/features/game/domain/models/card_feature_state.dart';
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/presentation/pages/game_board_screen.dart';
import 'package:halabessa/features/game/presentation/pages/offline_practice_app.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';
import 'package:halabessa/features/game/presentation/widgets/option_b_table.dart';
import 'package:halabessa/features/game/presentation/widgets/match_phase_panel.dart';
import 'package:halabessa/features/game/presentation/widgets/match_choice_panel.dart';
import 'offline_practice_isolation_test.dart' show QuietLocalAudio;

class _Translations extends AssetLoader {
  final Map<String, dynamic> data;
  const _Translations(this.data);
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}

void main() {
  for (final size in [
    const Size(1004, 430),
    const Size(430, 932),
    if (const bool.fromEnvironment('CARD_REVEAL_REFERENCE'))
      const Size(760, 430),
    if (const bool.fromEnvironment('CARD_REVEAL_REFERENCE'))
      const Size(430, 740),
  ]) {
    for (final scenario in [
      'play',
      'cut',
      if (const bool.fromEnvironment('HALABESSA_DECK_SPICES')) 'vote',
    ]) {
      final cut = scenario == 'cut';
      final vote = scenario == 'vote';
      testWidgets('actual tabletop reference $size $scenario', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await EasyLocalization.ensureInitialized();
        final translations = (await tester.runAsync(
          () async =>
              jsonDecode(
                    await rootBundle.loadString(
                      'assets/translations/ar-EG.json',
                    ),
                  )
                  as Map<String, dynamic>,
        ))!;
        await tester.runAsync(() async {
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          for (final entry in {
            'LanternText': 'Cairo.ttf',
            'LanternArabic': 'Cairo.ttf',
            'LanternDisplay': 'Righteous-Regular.ttf',
          }.entries) {
            await (FontLoader(
              entry.key,
            )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
          }
        });
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ...offlinePlayOverrides(
              prefs,
              AppUser(uid: 'LOCAL_reference', email: '', displayName: 'You'),
              audioFactory: (_) => QuietLocalAudio(),
            ),
          ],
        );
        const hand = [
          cards.Card(cards.Suit.clubs, cards.Rank.six),
          cards.Card(cards.Suit.diamonds, cards.Rank.nine),
          cards.Card(cards.Suit.clubs, cards.Rank.ace),
          cards.Card(cards.Suit.spades, cards.Rank.eight),
        ];
        const board = [
          cards.Card(cards.Suit.diamonds, cards.Rank.two),
          cards.Card(cards.Suit.clubs, cards.Rank.seven),
          cards.Card(cards.Suit.spades, cards.Rank.queen),
          cards.Card(cards.Suit.hearts, cards.Rank.four),
        ];
        const king = cards.Card(cards.Suit.diamonds, cards.Rank.king);
        const jack = cards.Card(cards.Suit.hearts, cards.Rank.jack);
        final spare =
            [
              for (final suit in cards.Suit.values)
                for (final rank in cards.Rank.values) cards.Card(suit, rank),
            ]..removeWhere(
              (card) => [...hand, ...board, king, jack].contains(card),
            );
        // 16 held + 4 on table + 16 collected + 16 in deck = 52, all unique.
        var state = MatchState(
          id: 'OFFLINE_REFERENCE',
          mode: GameMode.classic,
          playerIds: ['LOCAL_reference', 'bot_1', 'bot_2', 'bot_3'],
          phase: cut ? GamePhase.preRoundCut : GamePhase.playing,
          dealerIndex: cut ? 0 : 2,
          currentTurnIndex: 0,
          handInRound: cut ? 0 : 2,
          roundCount: 2,
          teamAScore: 9,
          teamBScore: 4,
          deckCount: cut ? 52 : 16,
          turnStartTime: DateTime.now(),
          timerDurationSeconds: 30,
          botDifficulties: const {
            'bot_1': 'hard',
            'bot_2': 'hard',
            'bot_3': 'expert',
          },
          handCards: cut
              ? {}
              : {
                  'LOCAL_reference': hand,
                  'bot_1': spare.sublist(0, 4),
                  'bot_2': spare.sublist(4, 8),
                  'bot_3': spare.sublist(8, 12),
                },
          board: cut ? [] : board,
          harvestStacks: cut
              ? {}
              : {
                  'teamA': [
                    Capture(
                      leadingCard: king,
                      capturedCards: spare.sublist(12, 16),
                    ),
                    Capture(
                      leadingCard: jack,
                      capturedCards: spare.sublist(16, 20),
                    ),
                  ],
                  'teamB': [
                    Capture(
                      leadingCard: spare[20],
                      capturedCards: spare.sublist(21, 26),
                    ),
                  ],
                },
        );
        if (vote) {
          state = state.copyWith(
            phase: GamePhase.shuffleVoting,
            phaseStartedAt: DateTime.now(),
            handCards: {},
            handCounts: {},
            board: [],
            deckCount: 0,
            harvestStacks: {
              'teamA': [
                Capture(
                  leadingCard: king,
                  capturedCards: [...hand, ...board, jack, ...spare],
                ),
              ],
              'teamB': [],
            },
          );
        }
        const revealReference = bool.fromEnvironment('CARD_REVEAL_REFERENCE');
        if (revealReference && scenario == 'play') {
          for (final uid in state.playerIds) {
            for (final card in state.handCards[uid]!.take(3)) {
              state = CardFeatureState(state).showLocal(uid, card);
            }
          }
        }
        final n = c.read(matchStateProvider.notifier);
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        n.state = state;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: EasyLocalization(
              supportedLocales: const [Locale('ar', 'EG')],
              startLocale: const Locale('ar', 'EG'),
              saveLocale: false,
              path: 'assets/translations',
              assetLoader: _Translations(translations),
              child: Builder(
                builder: (context) => MaterialApp(
                  theme: ThemeConfig.darkTheme,
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: RepaintBoundary(
                    key: key,
                    child: const GameBoardScreen(),
                  ),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump();
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
        }
        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.byType(TableSeat), findsNWidgets(4));
        final g = OptionBGeometry(size);
        expect(
          tester.getCenter(find.byKey(const ValueKey('option-b-board'))),
          size.center(Offset.zero),
        );
        expect(
          tester.getCenter(find.byKey(const ValueKey('option-b-hand'))).dx,
          closeTo(size.width / 2, .001),
        );
        if (scenario == 'play') {
          final partner = find.byWidgetPredicate(
            (w) => w is TableSeat && w.handOnRight,
          );
          expect(partner, findsOneWidget);
          final fan = tester.getRect(
            find.descendant(
              of: partner,
              matching: find.byKey(const ValueKey('seat-horizontal-fan')),
            ),
          );
          final avatar = tester.getRect(
            find.descendant(
              of: partner,
              matching: find.byKey(const ValueKey('avatar-feedback-circle')),
            ),
          );
          expect(fan.left, greaterThanOrEqualTo(avatar.right));
          expect(fan.right, lessThanOrEqualTo(size.width));
          for (final key in ['option-b-history', 'option-b-menu']) {
            expect(
              fan.overlaps(tester.getRect(find.byKey(ValueKey(key)))),
              isFalse,
            );
          }
        } else {
          var phase = tester.getRect(
            find.byType(vote ? MatchChoicePanel : MatchPhasePanel),
          );
          if (vote) {
            phase = phase.intersect(
              tester.getRect(find.byKey(const ValueKey('option-b-phase'))),
            );
          }
          for (final avatar
              in find
                  .byKey(const ValueKey('avatar-feedback-circle'))
                  .evaluate()) {
            expect(
              phase.overlaps(tester.getRect(find.byWidget(avatar.widget))),
              isFalse,
            );
          }
          if (vote) {
            for (final name in ['history', 'menu', 'scores']) {
              expect(
                phase.overlaps(
                  tester.getRect(find.byKey(ValueKey('option-b-$name'))),
                ),
                false,
              );
            }
            final viewport = tester.getRect(
              find.byKey(const ValueKey('option-b-phase')),
            );
            for (final type in [FilledButton, OutlinedButton]) {
              final button = tester.getRect(find.byType(type));
              expect(
                viewport.contains(button.topLeft),
                true,
                reason:
                    'vote choice must be visible without discovering a scroll',
              );
              expect(
                viewport.contains(button.bottomRight),
                true,
                reason: 'both vote choices must fit the attached prompt',
              );
            }
          }
        }
        expect(g.hand.top, g.size.height - (g.landscape ? 134 : 212));
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('TABLETOP_REFERENCE')) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('build/design-review')
              ..createSync(recursive: true);
            await File(
              '${folder.path}/tabletop-${size.width.toInt()}-$scenario${revealReference ? '-reveals' : ''}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (revealReference && scenario == 'play') {
          final shown = CardFeatureState(state).visible;
          expect(shown, hasLength(12));
          final protected = [
            for (final name in ['board', 'hand', 'history', 'menu', 'scores'])
              tester.getRect(find.byKey(ValueKey('option-b-$name'))),
            for (final avatar
                in find
                    .byKey(const ValueKey('avatar-feedback-circle'))
                    .evaluate())
              tester.getRect(find.byWidget(avatar.widget)),
            for (final fan
                in find.byKey(const ValueKey('seat-horizontal-fan')).evaluate())
              tester.getRect(find.byWidget(fan.widget)),
          ];
          for (final card in shown) {
            final rect = tester.getRect(
              find.byKey(ValueKey('shown-${card.eventId}')),
            );
            for (final area in protected) {
              expect(
                rect.overlaps(area),
                false,
                reason:
                    'Shown card ${card.ownerUid}/${card.card.firebaseKey} must not obscure live cards, HUD or an avatar',
              );
            }
            expect((Offset.zero & size).contains(rect.topLeft), true);
            expect((Offset.zero & size).contains(rect.bottomRight), true);
          }
        }
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await tester.pump(const Duration(seconds: 15));
      });
    }
  }
}
