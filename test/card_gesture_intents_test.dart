import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/presentation/widgets/fanned_hand_widget.dart';
import 'package:halabessa/features/game/presentation/widgets/hand_card_placement.dart';

const cards = [
  game.Card(game.Suit.clubs, game.Rank.six),
  game.Card(game.Suit.hearts, game.Rank.nine),
];
Finder slot(int i) => find.byKey(ValueKey('hand-card-${cards[i].firebaseKey}'));

void main() {
  final plays = <game.Card>[], slams = <game.Card>[], shows = <game.Card>[];
  var unavailable = 0;
  var holdPulses = 0;
  Future<void>? showPending;
  Widget hand(
    bool turn, {
    int slamLeft = 3,
    int revealLeft = 3,
    bool artwork = true,
    bool enabled = true,
    bool reducedMotion = false,
    List<game.Card> handCards = cards,
    void Function(game.Card, bool, bool)? selection,
    void Function(game.Card, bool, double, double)? visual,
  }) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: 360,
          child: FannedHandWidget(
            cards: handCards,
            interactionEnabled: enabled,
            isMyTurn: turn,
            renderArtwork: artwork,
            onCardTap: (c, _) => plays.add(c),
            onCardSlam: (c, _) => slams.add(c),
            onCardReveal: (c, _) {
              shows.add(c);
              return showPending;
            },
            slamUsesRemaining: slamLeft,
            revealUsesRemaining: revealLeft,
            onUnavailable: () => unavailable++,
            onHoldPulse: () => holdPulses++,
            onSelectionPose: selection,
            onVisualPose: visual,
            cardBuilder: (_, w, h) => SizedBox(width: w, height: h),
          ),
        ),
      ),
    ),
  );
  setUp(() {
    plays.clear();
    slams.clear();
    shows.clear();
    unavailable = 0;
    holdPulses = 0;
    showPending = null;
  });
  Future<void> hold(WidgetTester tester, int index) async {
    final gesture = await tester.startGesture(tester.getCenter(slot(index)));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
  }

  testWidgets(
    'hold pulses and artwork tremble stop at marking, not at release',
    (tester) async {
      await tester.pumpWidget(hand(false));
      await tester.pumpAndSettle();
      final target = tester.getRect(slot(0));
      final gesture = await tester.startGesture(target.center);
      await tester.pump(
        const Duration(milliseconds: 110),
      ); // existing tap-down recognition
      await tester.pump(
        const Duration(milliseconds: 190),
      ); // hold build-up, not a short tap
      await tester.pump(const Duration(milliseconds: 20));
      expect(holdPulses, greaterThan(0));
      final tremble = tester.widget<Transform>(
        find.byKey(ValueKey('hand-hold-tremble-${cards[0].firebaseKey}')),
      );
      expect(tremble.transform.getTranslation().x.abs(), greaterThan(0));
      expect(
        tester.getRect(slot(0)),
        target,
        reason: 'artwork moves, not the hit target',
      );
      await tester.pump(
        const Duration(milliseconds: 240),
      ); // marked by the unchanged recognizer
      final markedPulses = holdPulses;
      expect(
        find.byKey(ValueKey('hand-slam-outline-${cards[0].firebaseKey}')),
        cardUiRefinements ? findsNothing : findsOneWidget,
      );
      await tester.pump(
        const Duration(milliseconds: 300),
      ); // still physically held
      expect(holdPulses, markedPulses);
      expect(
        tester
            .widget<Transform>(
              find.byKey(ValueKey('hand-hold-tremble-${cards[0].firebaseKey}')),
            )
            .transform
            .getTranslation()
            .x,
        0,
      );
      await gesture.up();
      await tester.pump();
      expect(
        slams,
        isEmpty,
        reason: 'off-turn release queues, never plays early',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('short taps do not start the repeated hold feedback', (
    tester,
  ) async {
    await tester.pumpWidget(hand(false));
    await tester.pumpAndSettle();
    await tester.tap(slot(0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(holdPulses, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Unity receives temporary hold vibration through its existing private pose hook',
    (tester) async {
      final velocities = <double>[];
      await tester.pumpWidget(
        hand(
          false,
          artwork: false,
          visual: (card, peek, drag, speed) {
            if (card == cards[0]) velocities.add(speed);
          },
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(slot(0)));
      await tester.pump(const Duration(milliseconds: 110));
      await tester.pump(const Duration(milliseconds: 190));
      await tester.pump(const Duration(milliseconds: 20));
      expect(velocities.any((v) => v.abs() > 0), true);
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pump();
      expect(velocities.last, 0, reason: 'marking stops preparation vibration');
      await gesture.up();
      await tester.pump();
      expect(slams, isEmpty);
      expect(plays, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final cancellation in ['pointer', 'disabled', 'removed', 'background']) {
    testWidgets('hold feedback stops on $cancellation cancellation', (
      tester,
    ) async {
      await tester.pumpWidget(hand(false));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(slot(0)));
      await tester.pump(const Duration(milliseconds: 110));
      await tester.pump(const Duration(milliseconds: 190));
      expect(holdPulses, greaterThan(0));
      final pulsesBeforeCancel = holdPulses;
      switch (cancellation) {
        case 'pointer':
          await gesture.cancel();
        case 'disabled':
          await tester.pumpWidget(hand(false, enabled: false));
        case 'removed':
          await tester.pumpWidget(hand(false, handCards: [cards[1]]));
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
      }
      await tester.pump(const Duration(milliseconds: 350));
      expect(holdPulses, pulsesBeforeCancel);
      for (final tremble in tester.widgetList<Transform>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Transform &&
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith(
                'hand-hold-tremble-',
              ),
        ),
      )) {
        expect(tremble.transform.getTranslation().x, 0);
      }
      if (cancellation != 'pointer') await gesture.cancel();
      if (cancellation == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      expect(plays, isEmpty);
      expect(slams, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('reduced motion keeps hold pulses but removes artwork tremble', (
    tester,
  ) async {
    await tester.pumpWidget(hand(false, reducedMotion: true));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(slot(0)));
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 190));
    expect(holdPulses, greaterThan(0));
    expect(
      tester
          .widget<Transform>(
            find.byKey(ValueKey('hand-hold-tremble-${cards[0].firebaseKey}')),
          )
          .transform
          .getTranslation()
          .x,
      0,
    );
    await tester.pump(const Duration(milliseconds: 240));
    final markedPulses = holdPulses;
    await tester.pump(const Duration(milliseconds: 300));
    expect(holdPulses, markedPulses);
    await gesture.cancel();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a background-interrupted hold never queues a slam on release', (
    tester,
  ) async {
    await tester.pumpWidget(hand(false));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(slot(0)));
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 190));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 400));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await gesture.up();
    await tester.pumpWidget(hand(true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(plays, isEmpty);
    expect(slams, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'disabled feature preserves the existing held-tap release behavior',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: FannedHandWidget(
                  cards: cards,
                  isMyTurn: true,
                  onCardTap: (card, _) => plays.add(card),
                  cardBuilder: (_, w, h) => SizedBox(width: w, height: h),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await hold(tester, 0);
      expect(plays, [cards[0]]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('long press plays exactly one slam and never a normal tap', (
    tester,
  ) async {
    await tester.pumpWidget(hand(true));
    await tester.pumpAndSettle();
    await hold(tester, 0);
    expect(slams, [cards[0]]);
    expect(plays, isEmpty);
    expect(shows, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'holding a normal queued card upgrades delivery without cancelling selection',
    (tester) async {
      await tester.pumpWidget(hand(false));
      await tester.pumpAndSettle();
      await tester.tap(slot(0));
      await tester.pumpAndSettle();
      await hold(tester, 0);
      expect(
        find.byKey(const ValueKey('hand-slam-outline-clubs_six')),
        cardUiRefinements ? findsNothing : findsOneWidget,
      );
      await tester.pumpWidget(hand(true));
      await tester.pump(const Duration(milliseconds: 301));
      expect(slams, [cards[0]]);
      expect(plays, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('long press queues the slam style and short tap cancels it', (
    tester,
  ) async {
    await tester.pumpWidget(hand(false));
    await tester.pumpAndSettle();
    await hold(tester, 0);
    expect(slams, isEmpty);
    expect(
      find.byKey(const ValueKey('hand-slam-outline-clubs_six')),
      cardUiRefinements ? findsNothing : findsOneWidget,
    );
    await tester.tap(slot(0));
    await tester.pumpWidget(hand(true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(slams, isEmpty);
    expect(plays, isEmpty);
    await tester.tap(slot(1));
    expect(plays, [cards[1]]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('queued slam executes as slam when turn starts', (tester) async {
    await tester.pumpWidget(hand(false));
    await tester.pumpAndSettle();
    await hold(tester, 0);
    await tester.pumpWidget(hand(true));
    await tester.pump(const Duration(milliseconds: 350));
    expect(slams, [cards[0]]);
    expect(plays, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('tap cancels queued normal card in turn-entry grace window', (
    tester,
  ) async {
    await tester.pumpWidget(hand(false));
    await tester.pumpAndSettle();
    await tester.tap(slot(0));
    await tester.pumpWidget(hand(true));
    await tester.tap(slot(0));
    await tester.pump(const Duration(milliseconds: 350));
    expect(plays, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'downward show preserves queue and never consumes the normal play path',
    (tester) async {
      final pending = Completer<void>();
      showPending = pending.future;
      await tester.pumpWidget(hand(false));
      await tester.pumpAndSettle();
      await tester.tap(slot(0));
      await tester.drag(slot(1), const Offset(0, 70));
      await tester.pump();
      expect(shows, [cards[1]]);
      expect(plays, isEmpty);
      await tester.pumpWidget(hand(true));
      await tester.pump(const Duration(milliseconds: 350));
      expect(plays, [
        cards[0],
      ], reason: 'A pending reveal must not block the real turn');
      pending.complete();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('exhausted gestures never fall through to ordinary play', (
    tester,
  ) async {
    await tester.pumpWidget(hand(true, slamLeft: 0, revealLeft: 0));
    await tester.pumpAndSettle();
    await hold(tester, 0);
    await tester.drag(slot(1), const Offset(0, 70));
    expect(plays, isEmpty);
    expect(slams, isEmpty);
    expect(shows, isEmpty);
    expect(unavailable, 2);
    await tester.tap(slot(1));
    expect(plays, [cards[1]]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'remaining count is contextual and local selection survives hidden artwork',
    (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        hand(
          false,
          artwork: false,
          selection: (c, q, s) {
            if (q) selected.add(c.firebaseKey);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('hand-remaining-clubs_six')),
        findsNothing,
      );
      final gesture = await tester.startGesture(tester.getCenter(slot(0)));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('hand-remaining-clubs_six')),
        cardUiRefinements ? findsNothing : findsOneWidget,
      );
      await gesture.up();
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('hand-remaining-clubs_six')),
        findsNothing,
      );
      expect(selected, contains('clubs_six'));
      expect(find.textContaining('Next turn'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
