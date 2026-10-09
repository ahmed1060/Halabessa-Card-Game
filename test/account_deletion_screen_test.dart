import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/services/account_deletion_service.dart';
import 'package:halabessa/core/widgets/account_deletion_screen.dart';

class DeletionGuest extends Fake implements User {
  @override
  String get uid => 'qa-only';
  @override
  bool get isAnonymous => true;
  @override
  List<UserInfo> get providerData => [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> show(
    WidgetTester tester, {
    required String status,
    bool receipt = true,
    TextDirection direction = TextDirection.ltr,
    bool failure = false,
  }) async {
    if (receipt) await DeletionReceipt.prepare('qa-only');
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: AccountDeletionScreen(
            currentUser: () => null,
            loadStatus: (_) async {
              if (failure) throw StateError('private internal failure');
              return {'status': status};
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(430, 932),
    const Size(932, 430),
    const Size(320, 568),
  ]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'pending request fits $size $direction and cannot be discarded or called complete',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await show(tester, status: 'pending', direction: direction);
          expect(find.textContaining('not yet a completion'), findsOneWidget);
          expect(find.text('Cancel'), findsNothing);
          expect(find.text('Back to sign-in'), findsNothing);
          expect(find.byType(CheckboxListTile), findsNothing);
          expect(tester.takeException(), isNull);
          expect(await DeletionReceipt.load(), isNotNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('lost response keeps receipt even when status is not found yet', (
    tester,
  ) async {
    await show(tester, status: 'not_found');
    expect(find.text('Cancel'), findsNothing);
    expect(await DeletionReceipt.load(), isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'transport failure shows retry, not completion or internal details',
    (tester) async {
      await show(tester, status: 'pending', failure: true);
      expect(find.textContaining('Retry when you are online'), findsOneWidget);
      expect(find.textContaining('private internal failure'), findsNothing);
      expect(find.text('Back to sign-in'), findsNothing);
      expect(await DeletionReceipt.load(), isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'completion has a recovery exit and explicitly describes retained records',
    (tester) async {
      await show(tester, status: 'complete');
      expect(find.textContaining('Security tombstones'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Back to sign-in'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Back to sign-in'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('a guest must explicitly confirm before deletion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionScreen(currentUser: () => DeletionGuest()),
      ),
    );
    await tester.pumpAndSettle();
    FilledButton deleteButton() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(deleteButton().onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(deleteButton().onPressed, isNotNull);
    expect(await DeletionReceipt.load(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'a pending request blocks back navigation without dropping its receipt',
    (tester) async {
      await show(tester, status: 'pending');
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(await DeletionReceipt.load(), isNotNull);
      expect(find.byType(AccountDeletionScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
