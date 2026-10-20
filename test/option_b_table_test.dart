import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/widgets/settings_overlay.dart';
import 'package:halabessa/features/game/presentation/providers/chat_providers.dart';
import 'package:halabessa/features/game/presentation/widgets/dealer_seat.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as cards;
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/presentation/pages/offline_practice_app.dart';
import 'package:halabessa/features/game/presentation/pages/game_board_screen.dart';
import 'package:halabessa/features/game/presentation/widgets/option_b_table.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';
import 'package:halabessa/features/game/presentation/widgets/match_phase_panel.dart';
import 'package:halabessa/features/game/presentation/widgets/team_capture_stack.dart';
import 'package:halabessa/features/game/presentation/widgets/lantern_controls.dart';
import 'package:halabessa/features/game/presentation/widgets/turn_deadline_ring.dart';
import 'offline_practice_isolation_test.dart' show QuietLocalAudio;

const hand = [
  cards.Card(cards.Suit.clubs, cards.Rank.six),
  cards.Card(cards.Suit.diamonds, cards.Rank.nine),
  cards.Card(cards.Suit.clubs, cards.Rank.ace),
  cards.Card(cards.Suit.spades, cards.Rank.eight),
];
const capture = cards.Card(cards.Suit.clubs, cards.Rank.king);

class _ReviewTranslations extends AssetLoader {
  final Map<String, dynamic> data;
  const _ReviewTranslations(this.data);
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(430, 932),
    const Size(844, 390),
    const Size(932, 430),
    const Size(1280, 720),
  ]) {
    test('Option B physical geometry fits $size', () {
      final g = OptionBGeometry(size);
      final scene = Offset.zero & g.size;
      for (final r in [
        g.local,
        g.scores,
        g.history,
        g.menu,
        g.rivalPile,
        g.partner,
        g.deck,
        g.left,
        g.right,
        g.ourPile,
        g.hand,
        g.board,
        g.phase,
      ]) {
        expect(scene.contains(r.topLeft), isTrue);
        expect(r.right, lessThanOrEqualTo(scene.right));
        expect(r.bottom, lessThanOrEqualTo(scene.bottom));
      }
      expect(g.ourPile.overlaps(g.hand), isFalse);
      expect(g.right.overlaps(g.rivalPile), isFalse);
      expect(g.history.overlaps(g.menu), isFalse);
      expect(g.board.center, g.size.center(Offset.zero));
      expect(g.hand.center.dx, closeTo(g.size.width / 2, .001));
      expect(g.hand.top, g.size.height - (g.landscape ? 134 : 212));
      expect(g.board.overlaps(g.hand), isFalse);
    });
  }

  for (final rtl in [false, true]) {
    testWidgets(
      'clear scores stay physical LTR and swipe without scene reflow $rtl',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: const Scaffold(
                body: OptionBTable(
                  local: Text('local'),
                  partner: Text('partner'),
                  left: Text('left'),
                  right: Text('right'),
                  scores: ClearScoreDisplay(
                    ourScore: 9,
                    phase: 3,
                    rivalScore: 4,
                    label: 'scores',
                    hideLabel: 'Hide',
                    showLabel: 'Show',
                  ),
                  history: SizedBox(),
                  menu: SizedBox(),
                  ourPile: SizedBox(),
                  rivalPile: SizedBox(),
                  board: SizedBox(),
                  hand: Text('hand'),
                  phase: SizedBox(),
                  showPhase: false,
                ),
              ),
            ),
          ),
        );
        final before = tester.getRect(find.text('hand'));
        expect(
          tester.getCenter(find.text('9')).dx,
          lessThan(tester.getCenter(find.text('3')).dx),
        );
        expect(
          tester.getCenter(find.text('3')).dx,
          lessThan(tester.getCenter(find.text('4')).dx),
        );
        final glass =
            tester
                    .widget<Container>(
                      find.byKey(const ValueKey('clear-score-glass')),
                    )
                    .decoration
                as BoxDecoration;
        expect(glass.color!.a, lessThan(.1));
        await tester.fling(
          find.byType(ClearScoreDisplay),
          const Offset(0, -70),
          600,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          0,
        );
        expect(tester.getRect(find.text('hand')), before);
        await tester.fling(
          find.byType(ClearScoreDisplay),
          const Offset(0, 70),
          600,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          1,
        );
        expect(tester.getRect(find.text('hand')), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'compact team pile tile narrower than backs; history exposes no collected faces',
    (tester) async {
      Widget face(cards.Card c, double w, double h) =>
          SizedBox(key: ValueKey(c.firebaseKey), width: w, height: h);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CompactCollectedPile(
                  label: 'Team',
                  count: 5,
                  pileKey: GlobalKey(),
                  small: true,
                  backBuilder: (w, h) => SizedBox(width: w, height: h),
                ),
                TeamCapturePreview(
                  captures: const [
                    Capture(leadingCard: capture, capturedCards: hand),
                    Capture(
                      leadingCard: cards.Card(cards.Suit.clubs, cards.Rank.six),
                      capturedCards: [],
                      isRoundAward: true,
                    ),
                  ],
                  label: 'History',
                  faceBuilder: face,
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('collected-count-tile')))
            .width,
        lessThan(tester.getSize(find.byType(FaceDownStack)).width),
      );
      expect(find.byKey(ValueKey(capture.firebaseKey)), findsOneWidget);
      expect(find.byKey(ValueKey(hand.first.firebaseKey)), findsNothing);
    },
  );

  for (final size in [const Size(430, 932), const Size(932, 430)]) {
    testWidgets('real Option B board renders and accepts card taps at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await EasyLocalization.ensureInitialized();
      final translations = await tester.runAsync(
        () async =>
            jsonDecode(
                  await rootBundle.loadString('assets/translations/ar-EG.json'),
                )
                as Map<String, dynamic>,
      );
      if (const bool.fromEnvironment('OPTION_B_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final font = FontLoader('LanternText')
            ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
          await font.load();
          final arabic = FontLoader('LanternArabic')
            ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
          await arabic.load();
          final display = FontLoader('LanternDisplay')
            ..addFont(rootBundle.load('assets/fonts/Righteous-Regular.ttf'));
          await display.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...offlinePlayOverrides(
            prefs,
            AppUser(uid: 'LOCAL_visual', email: '', displayName: 'You'),
            audioFactory: (_) => QuietLocalAudio(),
          ),
        ],
      );
      final n = c.read(matchStateProvider.notifier);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      n.state = MatchState(
        id: 'OFFLINE_OPTION_B',
        mode: GameMode.classic,
        playerIds: ['LOCAL_visual', 'bot_1', 'bot_2', 'bot_3'],
        dealerIndex: 2,
        currentTurnIndex: 0,
        phase: GamePhase.playing,
        handInRound: 3,
        roundCount: 2,
        teamAScore: 9,
        teamBScore: 4,
        turnStartTime: DateTime.now(),
        deckCount: 32,
        botDifficulties: const {
          'bot_1': 'medium',
          'bot_2': 'hard',
          'bot_3': 'expert',
        },
        handCards: {
          'LOCAL_visual': hand,
          'bot_1': hand,
          'bot_2': hand,
          'bot_3': hand.take(3).toList(),
        },
        harvestStacks: const {
          'teamA': [Capture(leadingCard: capture, capturedCards: hand)],
          'teamB': [Capture(leadingCard: capture, capturedCards: hand)],
        },
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: EasyLocalization(
            supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
            path: 'assets/translations',
            startLocale: const Locale('ar', 'EG'),
            saveLocale: false,
            assetLoader: _ReviewTranslations(translations!),
            child: Builder(
              builder: (context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: RepaintBoundary(
                  key: boundaryKey,
                  child: const GameBoardScreen(),
                ),
              ),
            ),
          ),
        ),
      );
      for (
        var i = 0;
        i < 12 && find.byType(TableSeat).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(TableSeat), findsNWidgets(4));
      expect(find.byType(LanternTurnBadge), findsNothing);
      expect(find.byType(LanternControlButton), findsNothing);
      expect(find.byType(TurnDeadlineRing), findsNWidgets(4));
      // Optional reproducible design review images, not test goldens.
      if (const bool.fromEnvironment('OPTION_B_SCREENSHOTS')) {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory('build/design-review');
          await folder.create(recursive: true);
          await File(
            '${folder.path}/option-b-${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byWidgetPredicate((w) => w is TableSeat && w.chatBadge),
      );
      await tester.pump();
      expect(c.read(chatStateProvider).isOverlayOpen, isTrue);
      c.read(chatStateProvider.notifier).setOverlayOpen(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is PopupMenuItem<String> && w.value == 'settings',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(SettingsOverlay), findsOneWidget);
      Navigator.of(tester.element(find.byType(SettingsOverlay))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byType(TeamCapturePreview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(CaptureCardHistory), findsOneWidget);
      Navigator.of(tester.element(find.byType(CaptureCardHistory))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final initial = c.read(matchStateProvider)!;
      expect(find.byType(CompactCollectedPile), findsNothing);
      expect(
        find.byKey(const ValueKey('seat-horizontal-fan')),
        findsNWidgets(3),
      );
      expect(find.byKey(const ValueKey('history-our-count')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-rival-count')), findsOneWidget);
      Rect? fixedDeck;
      for (var dealer = 0; dealer < 4; dealer++) {
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        n.state = initial.copyWith(dealerIndex: dealer);
        await tester.pump();
        final partner = find.byWidgetPredicate(
          (w) => w is TableSeat && w.handOnRight,
        );
        final sideHand = tester.getRect(
          find.descendant(
            of: partner,
            matching: find.byKey(const ValueKey('seat-horizontal-fan')),
          ),
        );
        for (final name in ['history', 'menu']) {
          expect(
            sideHand.overlaps(
              tester.getRect(find.byKey(ValueKey('option-b-$name'))),
            ),
            isFalse,
            reason: 'Bot 2 hand avoids $name for dealer $dealer',
          );
        }
        final seat = tester.widget<DealDeck>(find.byType(DealDeck));
        final deck = tester.getRect(find.byKey(seat.deckKey!));
        fixedDeck ??= deck;
        expect(deck, fixedDeck, reason: 'deal deck has a fixed Option B slot');
        expect(
          deck.right,
          lessThan(
            tester.getCenter(find.byKey(const ValueKey('option-b-partner'))).dx,
          ),
          reason: 'deal deck stays left of top player, regardless of dealer',
        );
        expect(deck.left, greaterThanOrEqualTo(0));
        expect(deck.right, lessThanOrEqualTo(size.width));
        expect(deck.top, greaterThanOrEqualTo(0));
        expect(deck.bottom, lessThanOrEqualTo(size.height));
        expect(
          deck.overlaps(
            tester.getRect(find.byKey(const ValueKey('clear-score-glass'))),
          ),
          isFalse,
        );
        expect(
          deck.overlaps(
            tester.getRect(find.byKey(const ValueKey('option-b-rival-pile'))),
          ),
          isFalse,
        );
        for (final ring in find.byType(TurnDeadlineRing).evaluate()) {
          expect(
            deck.overlaps(tester.getRect(find.byWidget(ring.widget))),
            isFalse,
            reason: 'Dealer $dealer deck must not crowd another avatar',
          );
        }
      }
      for (var dealer = 0; dealer < 4; dealer++) {
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        n.state = initial.copyWith(
          phase: GamePhase.preRoundCut,
          dealerIndex: dealer,
        );
        await tester.pump();
        final cutPanel = tester.widget<MatchPhasePanel>(
          find.byType(MatchPhasePanel),
        );
        expect(cutPanel.onAction != null, dealer == 0);
        expect(
          cutPanel.actionLabel,
          dealer == 0 ? translations['cut_the_deck'] : null,
        );
      }
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      n.state = initial;
      await tester.pump();
      await tester.tap(
        find.byKey(ValueKey('hand-card-${hand.first.firebaseKey}')),
      );
      await tester.pump();
      expect(c.read(matchStateProvider)!.board, [hand.first]);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pump(const Duration(seconds: 15));
      expect(tester.takeException(), isNull);
    });
  }
}
