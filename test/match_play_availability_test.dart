import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/widgets/match_play_availability.dart';

void main() {
  testWidgets(
    'capture readiness wakes once and a newer deadline cancels the old one',
    (tester) async {
      final start = DateTime.utc(2026, 10, 12);
      var now = start;
      Widget view(DateTime? end) => MaterialApp(
        home: MatchPlayAvailability(
          availableAt: end,
          serverClock: false,
          now: () => now,
          builder: (ready) => Text(ready ? 'ready' : 'reading'),
        ),
      );
      await tester.pumpWidget(
        view(start.add(const Duration(milliseconds: 1400))),
      );
      expect(find.text('reading'), findsOneWidget);
      now = start.add(const Duration(milliseconds: 1399));
      await tester.pump(const Duration(milliseconds: 1399));
      expect(find.text('reading'), findsOneWidget);
      now = start.add(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('ready'), findsOneWidget);
      await tester.pumpWidget(view(start.add(const Duration(seconds: 3))));
      expect(find.text('reading'), findsOneWidget);
      await tester.pumpWidget(view(null));
      expect(find.text('ready'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );
}
