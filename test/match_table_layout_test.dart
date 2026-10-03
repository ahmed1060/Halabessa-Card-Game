import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';
import 'package:halabessa/features/game/presentation/widgets/match_phase_panel.dart';
import 'package:halabessa/features/game/presentation/widgets/table_style.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1191, 668)]) {
    testWidgets('G1 composition keeps table cards visible above hand: $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchTableLayout(
              header: const MatchScoreBar(
                firstLabel: 'Our team',
                secondLabel: 'Rivals',
                firstScore: 18,
                secondScore: 15,
                details: 'Round 3 · First to 41',
                roomLabel: 'Practice',
                onCopyRoom: null,
              ),
              partner: const TableSeat(name: 'Partner', detail: 'Cards: 4'),
              leftOpponent: const TableSeat(name: 'Left', detail: 'Cards: 4'),
              rightOpponent: const TableSeat(name: 'Right', detail: 'Cards: 4'),
              board: const SizedBox(
                key: ValueKey('g1-board'),
                width: 150,
                height: 100,
              ),
              collections: const SizedBox(height: 130),
              status: const Text('Your turn'),
              hand: const SizedBox(key: ValueKey('g1-hand'), height: 140),
              controls: const SizedBox(height: 48),
            ),
          ),
        ),
      );
      await tester.pump();
      final board = tester.getRect(find.byKey(const ValueKey('g1-board')));
      final hand = tester.getRect(find.byKey(const ValueKey('g1-hand')));
      expect(board.top, greaterThanOrEqualTo(0));
      expect(board.bottom, lessThanOrEqualTo(hand.top));
      expect(hand.bottom, lessThanOrEqualTo(size.height - 48));
      expect(tester.takeException(), isNull);
    });
  }
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          'table regions do not overlap: $size / $scale / $direction',
          (tester) async {
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            Widget seat(String name) =>
                TableSeat(name: name, detail: '4 cards');
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Directionality(
                    textDirection: direction,
                    child: Scaffold(
                      body: MatchTableLayout(
                        header: MatchScoreBar(
                          firstLabel: 'Our team',
                          secondLabel: 'Their team',
                          firstScore: 12,
                          secondScore: 8,
                          details: 'Round 2 · First to 41',
                          roomLabel: 'ABC123',
                          onCopyRoom: () {},
                        ),
                        partner: seat('Partner'),
                        leftOpponent: seat('Left'),
                        rightOpponent: seat('Right'),
                        board: const SizedBox(
                          key: ValueKey('board'),
                          width: 140,
                          height: 100,
                        ),
                        status: MatchPhasePanel(
                          title: 'Cut the deck',
                          message: 'Your turn to cut the deck',
                          actionLabel: 'Cut',
                          onAction: () async {},
                          failureMessage: 'Try again',
                        ),
                        hand: const SizedBox(
                          key: ValueKey('hand'),
                          height: 140,
                          width: 280,
                        ),
                        controls: IconButton(
                          onPressed: () {},
                          tooltip: 'Settings',
                          icon: const Icon(Icons.settings),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            final board = tester.getRect(find.byKey(const ValueKey('board')));
            final hand = tester.getRect(find.byKey(const ValueKey('hand')));
            final header = tester.getRect(find.byType(MatchScoreBar));
            expect(board.overlaps(hand), isFalse);
            expect(header.overlaps(hand), isFalse);
            for (final element in find.byType(TableSeat).evaluate()) {
              final seatRect = tester.getRect(find.byWidget(element.widget));
              expect(seatRect.overlaps(hand), isFalse);
              expect(seatRect.overlaps(header), isFalse);
            }
          },
        );
      }
    }
  }

  testWidgets('scores stay visible when the play area scrolls', (tester) async {
    const size = Size(320, 568);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: MatchTableLayout(
              header: const SizedBox(height: 80, child: Text('Score: 10')),
              partner: const SizedBox(height: 60),
              leftOpponent: const SizedBox(),
              rightOpponent: const SizedBox(),
              board: const SizedBox(height: 200, width: 230),
              status: const Text('Your turn'),
              hand: const SizedBox(height: 140),
              controls: const SizedBox(height: 48),
            ),
          ),
        ),
      ),
    );
    final headerBefore = tester.getRect(find.text('Score: 10'));
    await tester.dragFrom(const Offset(160, 300), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
    expect(tester.getRect(find.text('Score: 10')), headerBefore);
  });

  testWidgets('the hand tray does not collapse between deal and turn', (
    tester,
  ) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget table(Widget hand) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: size),
        child: Scaffold(
          body: MatchTableLayout(
            header: const SizedBox(height: 80),
            partner: const SizedBox(),
            leftOpponent: const SizedBox(),
            rightOpponent: const SizedBox(),
            board: const SizedBox(height: 200, width: 230),
            status: const Text('Phase'),
            hand: hand,
            controls: const SizedBox(height: 48),
          ),
        ),
      ),
    );
    await tester.pumpWidget(table(const SizedBox(height: 110)));
    final before = tester
        .getSize(find.byKey(const ValueKey('table-hand-tray')))
        .height;
    await tester.pumpWidget(table(const SizedBox.shrink()));
    final after = tester
        .getSize(find.byKey(const ValueKey('table-hand-tray')))
        .height;
    expect(before, 168);
    expect(after, before);
  });

  testWidgets('roomy landscape centers board and hand on the same table axis', (
    tester,
  ) async {
    const size = Size(1280, 720);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MatchTableLayout(
            header: SizedBox(height: 80),
            partner: SizedBox(height: 60),
            leftOpponent: SizedBox(),
            rightOpponent: SizedBox(),
            board: SizedBox(key: ValueKey('board'), width: 230, height: 200),
            status: Text('Your turn'),
            hand: SizedBox(key: ValueKey('hand'), width: 280, height: 110),
            controls: SizedBox(height: 48),
          ),
        ),
      ),
    );
    await tester.pump();
    final board = tester.getRect(find.byKey(const ValueKey('board')));
    final hand = tester.getRect(find.byKey(const ValueKey('hand')));
    expect(board.center.dx, closeTo(size.width / 2, 1));
    expect(hand.center.dx, closeTo(size.width / 2, 1));
    expect(board.bottom, lessThan(hand.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape tray keeps its width before and after dealing', (
    tester,
  ) async {
    const size = Size(1280, 720);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget table(Widget hand) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: size),
        child: Scaffold(
          body: MatchTableLayout(
            header: const SizedBox(height: 80),
            partner: const SizedBox(),
            leftOpponent: const SizedBox(),
            rightOpponent: const SizedBox(),
            board: const SizedBox(height: 200, width: 230),
            status: const Text('Waiting'),
            hand: hand,
            controls: const SizedBox(height: 48),
          ),
        ),
      ),
    );
    await tester.pumpWidget(table(const SizedBox.shrink()));
    final before = tester.getRect(
      find.byKey(const ValueKey('table-hand-tray')),
    );
    await tester.pumpWidget(table(const SizedBox(height: 110, width: 280)));
    final after = tester.getRect(find.byKey(const ValueKey('table-hand-tray')));
    expect(before.width, 980);
    expect(after.width, before.width);
    expect(after.center.dx, before.center.dx);
  });

  testWidgets('portrait tray keeps the viewport width while dealing', (
    tester,
  ) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget table(Widget hand) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: size),
        child: Scaffold(
          body: MatchTableLayout(
            header: const SizedBox(height: 80),
            partner: const SizedBox(),
            leftOpponent: const SizedBox(),
            rightOpponent: const SizedBox(),
            board: const SizedBox(height: 200, width: 230),
            status: const Text('Waiting'),
            hand: hand,
            controls: const SizedBox(height: 48),
          ),
        ),
      ),
    );
    await tester.pumpWidget(table(const SizedBox.shrink()));
    final before = tester.getRect(
      find.byKey(const ValueKey('table-hand-tray')),
    );
    await tester.pumpWidget(table(const SizedBox(height: 110, width: 280)));
    final after = tester.getRect(find.byKey(const ValueKey('table-hand-tray')));
    expect(before.width, size.width);
    expect(after.width, before.width);
    expect(after.center.dx, before.center.dx);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'partner activity and messages do not move the board at ${scale}x',
      (tester) async {
        const size = Size(390, 844);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        Widget table({required bool active, String? message}) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: MatchTableLayout(
                header: const SizedBox(height: 80),
                partner: TableSeat(
                  key: const ValueKey('partner'),
                  name: 'Bot 2',
                  detail: active ? 'Playing now' : 'Cards: 4',
                  active: active,
                  message: message,
                ),
                leftOpponent: const TableSeat(
                  name: 'Bot 3',
                  detail: 'Cards: 4',
                ),
                rightOpponent: const TableSeat(
                  name: 'Bot 1',
                  detail: 'Cards: 4',
                ),
                board: const SizedBox(
                  key: ValueKey('board'),
                  width: 230,
                  height: 200,
                ),
                status: const Text('Your turn'),
                hand: const SizedBox(height: 110),
                controls: const SizedBox(height: 48),
              ),
            ),
          ),
        );

        await tester.pumpWidget(table(active: false));
        final boardBefore = tester.getRect(find.byKey(const ValueKey('board')));
        final seatBefore = tester.getRect(
          find.byKey(const ValueKey('partner')),
        );
        final surface = find.descendant(
          of: find.byKey(const ValueKey('partner')),
          matching: find.byKey(const ValueKey('seat-active-surface')),
        );
        BoxDecoration decoration() =>
            tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
        expect((decoration().border! as Border).top.color, Colors.transparent);
        await tester.pumpWidget(table(active: true, message: '🔥'));
        expect(
          tester.getRect(find.byKey(const ValueKey('board'))),
          boardBefore,
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('partner'))),
          seatBefore,
        );
        expect(
          (decoration().border! as Border).top.color,
          TableStyle.brass.withOpacity(0.8),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('solo-practice label has no room-code copy affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MatchScoreBar(
            firstLabel: 'Our team',
            secondLabel: 'Their team',
            firstScore: 0,
            secondScore: 0,
            details: 'Round 1',
            roomLabel: 'Solo Practice',
            onCopyRoom: null,
          ),
        ),
      ),
    );
    expect(find.text('Solo Practice'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsNothing);
  });

  testWidgets('scoreboard separates labelled scores without punctuation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MatchScoreBar(
            firstLabel: 'Our team',
            secondLabel: 'Their team',
            firstScore: 12,
            secondScore: 8,
            details: 'Round 2',
            roomLabel: 'Solo Practice',
            onCopyRoom: null,
          ),
        ),
      ),
    );
    expect(find.text(':'), findsNothing);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    final firstScore = tester.getRect(find.text('12'));
    final secondScore = tester.getRect(find.text('8'));
    expect(firstScore.center.dx, lessThan(secondScore.center.dx));
    expect(firstScore.center.dy, secondScore.center.dy);
  });

  testWidgets('seat tooltip uses table colors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TableSeat(name: 'Bot 1', detail: 'Playing now', active: true),
        ),
      ),
    );
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    final decoration = tooltip.decoration! as BoxDecoration;
    expect(decoration.color, TableStyle.ink);
    expect(tooltip.textStyle!.color, TableStyle.ivory);
  });
}
