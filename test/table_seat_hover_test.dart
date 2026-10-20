import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';

void main() {
  testWidgets('seat hover paints only avatar circle and preserves clicks', (
    tester,
  ) async {
    var clicks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TableSeat(
              name: 'Player',
              detail: 'Hard',
              optionB: true,
              isBot: true,
              onPressed: () => clicks++,
            ),
          ),
        ),
      ),
    );
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.hoverColor, Colors.transparent);
    expect(ink.focusColor, Colors.transparent);
    expect(ink.highlightColor, Colors.transparent);
    expect(ink.splashColor, Colors.transparent);
    BoxDecoration circle() =>
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('avatar-feedback-circle')),
                )
                .decoration
            as BoxDecoration;
    expect(circle().shape, BoxShape.circle);
    expect(circle().boxShadow, isNull);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Player')));
    await tester.pump();
    expect(
      circle().boxShadow,
      isNull,
      reason: 'name/card space is not an avatar hover',
    );
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('avatar-hover-target'))),
    );
    await tester.pump();
    expect(circle().boxShadow, isNotEmpty);
    expect(circle().shape, BoxShape.circle);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(circle().boxShadow, isNull);
    await tester.tap(find.text('Player'));
    expect(clicks, 1);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
