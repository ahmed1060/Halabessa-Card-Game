import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/services/supabase_backend_service.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/home/presentation/widgets/room_entry_errors.dart';
import 'package:halabessa/features/home/presentation/widgets/room_entry_forms.dart';

Widget creation(Future<void> Function(RoomCreationConfig) action,
    {VoidCallback? completed, double scale = 1, double keyboard = 0,
    Size size = const Size(800, 600)}) =>
  MaterialApp(home: MediaQuery(data: MediaQueryData(
    size: size, textScaler: TextScaler.linear(scale),
    viewInsets: EdgeInsets.only(bottom: keyboard)),
    child: Scaffold(body: Align(alignment: Alignment.bottomCenter,
      child: RoomEntrySheet(child: RoomCreationForm(
        text: (key) => key, onCreate: action,
        onCreated: completed ?? () {}))))));

Widget joining(Future<void> Function(String) action,
    {VoidCallback? completed, double scale = 1, double keyboard = 0,
    Size size = const Size(800, 600)}) =>
  MaterialApp(home: MediaQuery(data: MediaQueryData(
    size: size, textScaler: TextScaler.linear(scale),
    viewInsets: EdgeInsets.only(bottom: keyboard)),
    child: Scaffold(body: Align(alignment: Alignment.bottomCenter,
      child: RoomEntrySheet(child: RoomJoinForm(
        text: (key) => key, onJoin: action,
        onJoined: completed ?? () {}))))));

void main() {
  test('room codes match the server contract', () {
    expect(normalizeRoomCode(' abc12345 '), 'ABC12345');
    expect(isValidRoomCode('abc12345'), isTrue);
    expect(isValidRoomCode('AB123456'), isFalse);
    expect(isValidRoomCode('ABC1234'), isFalse);
    expect(isValidRoomCode('ABC123456'), isFalse);
    expect(joinRoomErrorKey(const SupabaseBackendException('room_not_found')),
      'room_join_not_found');
    expect(joinRoomErrorKey(const SupabaseBackendException('room_not_joinable')),
      'room_join_closed');
    expect(joinRoomErrorKey(const SupabaseBackendException('room_full')),
      'error_room_full');
    expect(joinRoomErrorKey(StateError('internal details')),
      'error_service_unavailable');
    expect(createRoomErrorKey(const SupabaseBackendException('unauthenticated')),
      'room_sign_in_required');
  });

  testWidgets('room configuration is chosen before one explicit create action', (tester) async {
    RoomCreationConfig? sent;
    var completed = 0;
    await tester.pumpWidget(creation((config) async { sent = config; },
      completed: () => completed++));
    expect(sent, isNull);
    await tester.tap(find.byKey(const ValueKey('mode_tafweet')));
    await tester.tap(find.byKey(const ValueKey('score_21')));
    await tester.tap(find.byKey(const ValueKey('timer_0')));
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.ensureVisible(find.byKey(const ValueKey('create_room_submit')));
    await tester.tap(find.byKey(const ValueKey('create_room_submit')));
    await tester.pump();
    expect(sent?.mode, GameMode.tafweet);
    expect(sent?.maxPoints, 21);
    expect(sent?.timerSeconds, 0);
    expect(sent?.isPublic, isTrue);
    expect(completed, 1);
  });

  testWidgets('pending create blocks repeats and leaves error in the sheet', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(creation((_) { calls++; return pending.future; }));
    await tester.ensureVisible(find.byKey(const ValueKey('create_room_submit')));
    await tester.tap(find.byKey(const ValueKey('create_room_submit')));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('create_room_submit'))).onPressed, isNull);
    pending.completeError(const SupabaseBackendException('backend_unavailable'));
    await tester.pump();
    expect(find.text('room_create_failed'), findsOneWidget);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('create_room_submit'))).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('join validates format and normalizes lowercase before the request', (tester) async {
    String? sent;
    var completed = 0;
    await tester.pumpWidget(joining((code) async { sent = code; },
      completed: () => completed++));
    await tester.tap(find.byKey(const ValueKey('join_room_submit')));
    await tester.pump();
    expect(find.byKey(const ValueKey('join_room_error')), findsOneWidget);
    expect(find.text('room_code_format'), findsOneWidget);
    expect(sent, isNull);
    await tester.enterText(find.byKey(const ValueKey('room_code_input')), 'abc12345');
    await tester.tap(find.byKey(const ValueKey('join_room_submit')));
    await tester.pump();
    expect(sent, 'ABC12345');
    expect(completed, 1);
  });

  testWidgets('specific join failure stays visible and allows retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(joining((_) async {
      calls++;
      throw const SupabaseBackendException('room_full');
    }));
    await tester.enterText(find.byKey(const ValueKey('room_code_input')), 'ABC12345');
    await tester.tap(find.byKey(const ValueKey('join_room_submit')));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('error_room_full'), findsOneWidget);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('join_room_submit'))).onPressed, isNotNull);
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('room sheets scroll at $size and large text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(creation((_) async {}, scale: 2, size: size));
      await tester.ensureVisible(find.byKey(const ValueKey('create_room_submit')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(joining((_) async {}, scale: 2,
        keyboard: 150, size: size));
      await tester.ensureVisible(find.byKey(const ValueKey('join_room_submit')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
