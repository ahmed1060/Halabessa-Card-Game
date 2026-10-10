import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:halabessa/core/services/backend_transport.dart';

void main() {
  late String? session;
  BackendTransport transport(
    Future<http.Response> Function(http.Request) send, {
    Future<String?> Function()? token,
    String? region,
    String? commandRegion,
  }) => BackendTransport(
    endpoint: Uri.parse('https://backend.invalid/api'),
    client: MockClient(send),
    sessionKey: () => session,
    token: token ?? () async => 'test-token',
    preferredReadRegion: region,
    preferredCommandRegion: commandRegion,
  );
  setUp(() => session = 'A:1');

  test(
    'command route outage cools down subsequent calls, not auth refusals',
    () async {
      for (final status in [503, 403]) {
        final routes = <String?>[];
        final backend = transport((request) async {
          routes.add(request.headers['x-region']);
          expect(jsonDecode(request.body)['commandId'], 'same-id');
          return routes.length == 1
              ? http.Response('{"error":"denied"}', status)
              : http.Response('{}', 200);
        }, commandRegion: 'eu-west-2');
        await expectLater(
          backend.call('submitMatchCommand', data: {'commandId': 'same-id'}),
          throwsA(isA<SupabaseBackendException>()),
        );
        expect(routes.length, 1);
        await backend.call(
          'submitMatchCommand',
          data: {'commandId': 'same-id'},
        );
        expect(routes, ['eu-west-2', status == 503 ? null : 'eu-west-2']);
      }
    },
  );

  test(
    'command routing is scoped and never fails over after ambiguity',
    () async {
      for (final transportFailure in [false, true]) {
        var calls = 0;
        final backend = transport((request) async {
          calls++;
          expect(request.headers['x-region'], 'eu-west-2');
          expect(jsonDecode(request.body)['commandId'], 'same-id');
          if (transportFailure) throw http.ClientException('lost reply');
          return http.Response('{"error":"backend_busy"}', 503);
        }, commandRegion: 'eu-west-2');
        await expectLater(
          backend.call('submitMatchCommand', data: {'commandId': 'same-id'}),
          throwsA(isA<Exception>()),
        );
        expect(calls, 1);
      }
    },
  );

  test(
    'command preference does not force other writes into a region',
    () async {
      final backend = transport((request) async {
        expect(request.headers['x-region'], isNull);
        return http.Response('{}', 200);
      }, commandRegion: 'eu-west-2');
      for (final action in [
        'createRoom',
        'joinRoom',
        'claimDailyReward',
        'requestAccountDeletion',
      ]) {
        await backend.call(action);
      }
    },
  );

  test(
    'ordinary reads prefer London and fail over once on a gateway failure',
    () async {
      final routes = <String?>[];
      final backend = transport((request) async {
        routes.add(request.headers['x-region']);
        expect(jsonDecode(request.body)['action'], 'getMatchSnapshot');
        return routes.length == 1
            ? http.Response('unavailable', 503)
            : http.Response('{"version":7}', 200);
      }, region: 'eu-west-2');
      expect((await backend.call('getMatchSnapshot'))['version'], 7);
      expect(routes, ['eu-west-2', null]);
    },
  );

  test(
    'read transport failure falls back but authorization refusals do not',
    () async {
      var calls = 0;
      final backend = transport((request) async {
        calls++;
        if (calls == 1) throw http.ClientException('connection failed');
        expect(request.headers['x-region'], isNull);
        return http.Response('{}', 200);
      }, region: 'eu-west-2');
      await backend.call('getSocialGraph');
      expect(calls, 2);
      for (final status in [401, 403, 409]) {
        calls = 0;
        final denied = transport((_) async {
          calls++;
          return http.Response('{"error":"denied"}', status);
        }, region: 'eu-west-2');
        await expectLater(
          denied.call('getSocialGraph'),
          throwsA(isA<SupabaseBackendException>()),
        );
        expect(calls, 1);
      }
    },
  );

  test('preferred read region never reroutes or retries a mutation', () async {
    var calls = 0;
    final backend = transport((request) async {
      calls++;
      expect(request.headers['x-region'], isNull);
      return http.Response('{"error":"backend_busy"}', 503);
    }, region: 'eu-west-2');
    await expectLater(
      backend.call('submitMatchCommand'),
      throwsA(isA<SupabaseBackendException>()),
    );
    expect(calls, 1);
  });

  test(
    'logout during a failed regional read prevents automatic-route fallback',
    () async {
      var calls = 0;
      final backend = transport((_) async {
        calls++;
        session = null;
        return http.Response('unavailable', 503);
      }, region: 'eu-west-2');
      await expectLater(
        backend.call('getAdminStatus'),
        throwsA(isA<SupabaseBackendException>()),
      );
      expect(calls, 1);
    },
  );

  test(
    'a late regional response cannot overwrite the fallback result',
    () async {
      final late = Completer<http.Response>();
      var calls = 0;
      final backend = BackendTransport(
        endpoint: Uri.parse('https://backend.invalid/api'),
        client: MockClient((request) async {
          calls++;
          return request.headers['x-region'] != null
              ? late.future
              : http.Response('{"version":9}', 200);
        }),
        sessionKey: () => session,
        token: () async => 'test-token',
        preferredReadRegion: 'eu-west-2',
        regionalReadTimeout: const Duration(milliseconds: 5),
      );
      final response = await backend.call('getMatchSnapshot');
      expect(response['version'], 9);
      expect(calls, 2);
      late.complete(http.Response('{"version":2}', 200));
      await Future<void>.delayed(Duration.zero);
      expect(response['version'], 9);
    },
  );

  test('identical concurrent reads coalesce but never cache results', () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final backend = transport((_) {
      calls++;
      return pending.future;
    });
    final first = backend.call('getSocialGraph');
    final second = backend.call('getSocialGraph');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    pending.complete(http.Response('{"friends":["F"]}', 200));
    final a = await first;
    final b = await second;
    (a['friends'] as List).clear();
    expect(b['friends'], ['F']);
    await backend.call('getSocialGraph');
    expect(calls, 2);
  });

  test('mutations are never deduplicated or automatically retried', () async {
    var calls = 0;
    final backend = transport((_) async {
      calls++;
      return http.Response('{"error":"backend_busy"}', 503);
    });
    await Future.wait(
      List.generate(
        2,
        (_) => expectLater(
          backend.call('claimDailyReward'),
          throwsA(isA<SupabaseBackendException>()),
        ),
      ),
    );
    expect(calls, 2);
  });

  test('requests snapshot the body before awaiting the token', () async {
    final token = Completer<String?>();
    final data = <String, dynamic>{'roomId': 'QA', 'action': 'fake'};
    final backend = transport((request) async {
      expect(jsonDecode(request.body), {
        'roomId': 'QA',
        'action': 'getMatchSnapshot',
      });
      return http.Response('{}', 200);
    }, token: () => token.future);
    final request = backend.call('getMatchSnapshot', data: data);
    data['roomId'] = 'changed';
    token.complete('test-token');
    await request;
  });

  test(
    'logout rejects old reads and another session cannot share them',
    () async {
      var calls = 0;
      final pending = Completer<http.Response>();
      final backend = transport((_) {
        calls++;
        return pending.future;
      });
      final old = backend.call('getSocialGraph');
      final rejected = expectLater(
        old,
        throwsA(isA<SupabaseBackendException>()),
      );
      await Future<void>.delayed(Duration.zero);
      session = 'B:2';
      final next = backend.call('getSocialGraph');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      pending.complete(http.Response('{}', 200));
      await rejected;
      expect(await next, isEmpty);
    },
  );

  test('token wait is bounded and cannot launch a late mutation', () async {
    var calls = 0;
    final token = Completer<String?>();
    final backend = transport((_) async {
      calls++;
      return http.Response('{}', 200);
    }, token: () => token.future);
    await expectLater(
      backend.call(
        'claimDailyReward',
        timeout: const Duration(milliseconds: 5),
      ),
      throwsA(isA<TimeoutException>()),
    );
    token.complete('test-token');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(calls, 0);
  });

  test(
    'malformed gateway responses become a controlled backend error',
    () async {
      for (final body in ['<html>unavailable</html>', '[]', 'null']) {
        final backend = transport((_) async => http.Response(body, 502));
        await expectLater(
          backend.call('getSocialGraph'),
          throwsA(
            isA<SupabaseBackendException>().having(
              (e) => e.code,
              'code',
              'backend_unavailable',
            ),
          ),
        );
      }
    },
  );
}
