import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/services/account_deletion_service.dart';
import 'package:halabessa/core/services/supabase_backend_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'receipt is saved before submission, recoverable and stable for the same user',
    () async {
      expect(await DeletionReceipt.load(), isNull);
      final first = await DeletionReceipt.prepare('qa-only');
      expect(first.receipt, matches(RegExp(r'^[a-f0-9]{64}$')));
      final reloaded = await DeletionReceipt.load();
      expect(reloaded!.uid, 'qa-only');
      expect(reloaded.receipt, first.receipt);
      expect((await DeletionReceipt.prepare('qa-only')).receipt, first.receipt);
    },
  );
  test(
    'an outstanding receipt cannot be overwritten with another account',
    () async {
      final first = await DeletionReceipt.prepare('qa-one');
      await expectLater(
        DeletionReceipt.prepare('qa-two'),
        throwsA(isA<SupabaseBackendException>()),
      );
      expect((await DeletionReceipt.load())!.receipt, first.receipt);
      expect((await DeletionReceipt.load())!.uid, 'qa-one');
    },
  );
  test(
    'random receipts are independent; explicit forgetting removes only their preference',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('unrelated_setting', 'preserved');
      final first = await DeletionReceipt.prepare('qa-one');
      await DeletionReceipt.forget();
      expect(await DeletionReceipt.load(), isNull);
      final second = await DeletionReceipt.prepare('qa-one');
      expect(second.receipt, isNot(first.receipt));
      expect(prefs.getString('unrelated_setting'), 'preserved');
    },
  );
  test('malformed local data never supplies a deletion credential', () async {
    final prefs = await SharedPreferences.getInstance();
    for (final value in [
      '{bad',
      jsonEncode({'uid': 'qa', 'receipt': 'short'}),
      jsonEncode({'uid': 7, 'receipt': 'a' * 64}),
    ]) {
      await prefs.setString(DeletionReceipt.preferenceKey, value);
      expect(await DeletionReceipt.load(), isNull);
    }
  });
}
