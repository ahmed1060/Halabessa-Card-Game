import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/presentation/widgets/username_editor.dart';

Widget editor({required Future<bool> Function(String) check,
  required Future<void> Function(String) save, VoidCallback? saved}) => MaterialApp(
    home: Scaffold(body: UsernameEditor(title: 'Choose a username',
      description: 'Set a name so friends can find you.', fieldLabel: 'Username',
      saveLabel: 'Save', invalidMessage: 'Invalid name', takenMessage: 'Name taken',
      failureMessage: 'Try again', retryLabel: 'Retry check', onCheck: check,
      onSave: save, onSaved: saved ?? () {}, onClose: () {})));

void main() {
  testWidgets('late availability cannot enable saving a different name', (tester) async {
    final first = Completer<bool>();
    final second = Completer<bool>();
    await tester.pumpWidget(editor(check: (name) => name == 'first' ? first.future : second.future,
      save: (_) async {}));
    await tester.enterText(find.byType(TextField), 'first');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'second');
    first.complete(true);
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    second.complete(false);
    await tester.pump();
    expect(find.text('Name taken'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
  testWidgets('save failure stays visible; pending save cannot be duplicated', (tester) async {
    final pending = Completer<void>();
    var saves = 0, successes = 0;
    await tester.pumpWidget(editor(check: (_) async => true,
      save: (_) { saves++; return pending.future; }, saved: () => successes++));
    await tester.enterText(find.byType(TextField), 'player');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    pending.completeError(StateError('permission-denied'));
    await tester.pump();
    expect(saves, 1);
    expect(successes, 0);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('permission-denied'), findsNothing);
  });
  testWidgets('editing immediately invalidates a previous successful check', (tester) async {
    await tester.pumpWidget(editor(check: (_) async => true, save: (_) async {}));
    await tester.enterText(find.byType(TextField), 'player');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField), 'new_player');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('availability failure can retry and late responses tolerate disposal', (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(editor(check: (_) {
      if (++calls == 1) return Future<bool>.error(StateError('offline'));
      return pending.future;
    }, save: (_) async {}));
    await tester.enterText(find.byType(TextField), 'player');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text('Retry check'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
    pending.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
