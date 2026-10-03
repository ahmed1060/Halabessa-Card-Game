import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/services/daily_streak_service.dart';
import 'package:halabessa/features/home/presentation/widgets/daily_streak_dialog.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets('reward sheet fits $size $scale $direction', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(ProviderScope(child: MaterialApp(home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
            child: Directionality(textDirection: direction, child: Scaffold(body: DailyStreakDialog(
              status: DailyStreakStatus(currentStreak: 1, isClaimableToday: true,
                todayReward: DailyStreakService.schedule.first, schedule: DailyStreakService.schedule),
            ))),
          ))));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(FilledButton), findsOneWidget);
          expect(find.byType(SingleChildScrollView), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
