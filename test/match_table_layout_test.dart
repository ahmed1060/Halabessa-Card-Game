import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';
import 'package:halabessa/features/game/presentation/widgets/match_phase_panel.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844),
    const Size(844, 390), const Size(1024, 768)]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets('table regions do not overlap: $size / $scale / $direction', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          Widget seat(String name) => TableSeat(name: name, detail: '4 cards');
          await tester.pumpWidget(MaterialApp(home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
            child: Directionality(textDirection: direction, child: Scaffold(body: MatchTableLayout(
              header: MatchScoreBar(firstLabel: 'Our team', secondLabel: 'Their team',
                firstScore: 12, secondScore: 8, details: 'Round 2 · First to 41',
                roomLabel: 'ABC123', onCopyRoom: () {}),
              partner: seat('Partner'), leftOpponent: seat('Left'), rightOpponent: seat('Right'),
              board: const SizedBox(key: ValueKey('board'), width: 140, height: 100),
              status: MatchPhasePanel(title: 'Cut the deck', message: 'Your turn to cut the deck',
                actionLabel: 'Cut', onAction: () async {}, failureMessage: 'Try again'),
              hand: const SizedBox(key: ValueKey('hand'), height: 140, width: 280),
              controls: IconButton(onPressed: () {}, tooltip: 'Settings', icon: const Icon(Icons.settings)),
            ))),
          )));
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
        });
      }
    }
  }

  testWidgets('scores stay visible when the play area scrolls', (tester) async {
    const size = Size(320, 568);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(size: size, textScaler: TextScaler.linear(2)),
      child: Scaffold(body: MatchTableLayout(
        header: const SizedBox(height: 80, child: Text('Score: 10')),
        partner: const SizedBox(height: 60), leftOpponent: const SizedBox(),
        rightOpponent: const SizedBox(),
        board: const SizedBox(height: 200, width: 230),
        status: const Text('Your turn'),
        hand: const SizedBox(height: 140),
        controls: const SizedBox(height: 48),
      )),
    )));
    final headerBefore = tester.getRect(find.text('Score: 10'));
    await tester.dragFrom(const Offset(160, 300), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(0));
    expect(tester.getRect(find.text('Score: 10')), headerBefore);
  });

  testWidgets('the hand tray does not collapse between deal and turn', (tester) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget table(Widget hand) => MaterialApp(home: MediaQuery(
      data: const MediaQueryData(size: size),
      child: Scaffold(body: MatchTableLayout(
        header: const SizedBox(height: 80), partner: const SizedBox(),
        leftOpponent: const SizedBox(), rightOpponent: const SizedBox(),
        board: const SizedBox(height: 200, width: 230),
        status: const Text('Phase'), hand: hand,
        controls: const SizedBox(height: 48),
      )),
    ));
    await tester.pumpWidget(table(const SizedBox(height: 110)));
    final before = tester.getSize(find.byKey(const ValueKey('table-hand-tray'))).height;
    await tester.pumpWidget(table(const SizedBox.shrink()));
    final after = tester.getSize(find.byKey(const ValueKey('table-hand-tray'))).height;
    expect(before, 168);
    expect(after, before);
  });

  testWidgets('roomy landscape centers board and hand on the same table axis', (tester) async {
    const size = Size(1280, 720);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MatchTableLayout(
      header: SizedBox(height: 80), partner: SizedBox(height: 60),
      leftOpponent: SizedBox(), rightOpponent: SizedBox(),
      board: SizedBox(key: ValueKey('board'), width: 230, height: 200),
      status: Text('Your turn'),
      hand: SizedBox(key: ValueKey('hand'), width: 280, height: 110),
      controls: SizedBox(height: 48),
    ))));
    await tester.pump();
    final board = tester.getRect(find.byKey(const ValueKey('board')));
    final hand = tester.getRect(find.byKey(const ValueKey('hand')));
    expect(board.center.dx, closeTo(size.width / 2, 1));
    expect(hand.center.dx, closeTo(size.width / 2, 1));
    expect(board.bottom, lessThan(hand.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape tray keeps its width before and after dealing', (tester) async {
    const size = Size(1280, 720);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget table(Widget hand) => MaterialApp(home: MediaQuery(
      data: const MediaQueryData(size: size),
      child: Scaffold(body: MatchTableLayout(
        header: const SizedBox(height: 80), partner: const SizedBox(),
        leftOpponent: const SizedBox(), rightOpponent: const SizedBox(),
        board: const SizedBox(height: 200, width: 230),
        status: const Text('Waiting'), hand: hand,
        controls: const SizedBox(height: 48),
      )),
    ));
    await tester.pumpWidget(table(const SizedBox.shrink()));
    final before = tester.getRect(find.byKey(const ValueKey('table-hand-tray')));
    await tester.pumpWidget(table(const SizedBox(height: 110, width: 280)));
    final after = tester.getRect(find.byKey(const ValueKey('table-hand-tray')));
    expect(before.width, 980);
    expect(after.width, before.width);
    expect(after.center.dx, before.center.dx);
  });

  testWidgets('solo-practice label has no room-code copy affordance', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MatchScoreBar(
      firstLabel: 'Our team', secondLabel: 'Their team',
      firstScore: 0, secondScore: 0, details: 'Round 1',
      roomLabel: 'Solo Practice', onCopyRoom: null,
    ))));
    expect(find.text('Solo Practice'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsNothing);
  });
}
