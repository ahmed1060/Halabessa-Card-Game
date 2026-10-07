import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/home/presentation/pages/leaderboard_screen.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(932, 430)]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'weekly ranking uses weekly values and fits $size $direction',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final user = AppUser(
            uid: 'qa',
            email: '',
            displayName: 'QA Player',
            points: 98765,
          );
          final weekly = user.copyWith(points: 50, wins: 1, bestScore: 41);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                currentUserProvider.overrideWithValue(user),
                for (final category in LeaderboardCategory.values) ...[
                  leaderboardProvider(
                    category,
                  ).overrideWith((ref) async => [user]),
                  weeklyLeaderboardProvider(
                    category,
                  ).overrideWith((ref) async => [weekly]),
                ],
              ],
              child: MaterialApp(
                home: Directionality(
                  textDirection: direction,
                  child: const LeaderboardScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('ui_this_week'));
          await tester.pumpAndSettle();
          expect(find.text('50 ⭐'), findsWidgets);
          expect(find.text('98765 ⭐'), findsNothing);
          await tester.tap(find.text('tab_wins'));
          await tester.pumpAndSettle();
          expect(find.text('1 🏆'), findsWidgets);
          expect(find.text('ui_week_resets'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('failed ranking is not replaced with fictional players', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          leaderboardProvider(
            LeaderboardCategory.stars,
          ).overrideWith((ref) async => throw StateError('transport failed')),
        ],
        child: const MaterialApp(home: LeaderboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ui_leaderboard_unavailable'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.textContaining('transport failed'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
