import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:halabessa/core/services/idempotent_match_request.dart';
import 'package:halabessa/core/services/supabase_backend_service.dart';

void main() {
  final card = {'suit': 'hearts', 'rank': 'ace'};
  Map<String, dynamic> intent() => {'commandId': 'same-uuid', 'expectedVersion': 7,
    'commandType': 'playCard', 'commandPayload': {'card': Map.of(card)}};
  test('uncertain response retries the identical command, not a second move', () async {
    final sent = <Map<String, dynamic>>[];
    final result = await sendIdempotentMatchRequest(intent(), (request) async {
      sent.add(request);
      if (sent.length == 1) throw TimeoutException('response lost after commit');
      return {'ok': true, 'duplicate': true};
    });
    expect(sent, hasLength(2));
    expect(sent[0], sent[1]);
    expect(result['duplicate'], isTrue);
  });
  test('original and transport-side payload mutation cannot change a retry', () async {
    final original = intent();
    var attempts = 0;
    await sendIdempotentMatchRequest(original, (request) async {
      attempts++;
      expect(request['expectedVersion'], 7);
      expect((request['commandPayload'] as Map)['card'], card);
      if (attempts == 1) {
        original['expectedVersion'] = 9;
        ((request['commandPayload'] as Map)['card'] as Map)['rank'] = 'king';
        throw http.ClientException('connection reset');
      }
      return {'ok': true};
    });
    expect(attempts, 2);
  });
  test('version rejection is surfaced with current snapshot, never retried', () async {
    var attempts = 0;
    const error = SupabaseBackendException('version_conflict', details: {'currentVersion': 8});
    await expectLater(sendIdempotentMatchRequest(intent(), (_) async {
      attempts++; throw error;
    }), throwsA(same(error)));
    expect(attempts, 1);
    expect(error.details['currentVersion'], 8);
  });
  test('transport retry is bounded and a second failure is surfaced', () async {
    var attempts = 0;
    await expectLater(sendIdempotentMatchRequest(intent(), (_) async {
      attempts++; throw TimeoutException('offline');
    }), throwsA(isA<TimeoutException>()));
    expect(attempts, 2);
  });
}
