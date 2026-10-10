import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class SupabaseBackendException implements Exception {
  final String code;
  final Map<String, dynamic> details;
  const SupabaseBackendException(this.code, {this.details = const {}});
  @override
  String toString() => code;
}

/// Reuses the native connection pool. Only identical, concurrent reads are
/// coalesced; no response cache, authorization cache or mutation retry exists.
class BackendTransport {
  BackendTransport({
    required this.endpoint,
    required this.client,
    required this.sessionKey,
    required this.token,
    this.onTiming,
  });

  final Uri endpoint;
  final http.Client client;
  final Object? Function() sessionKey;
  final Future<String?> Function() token;
  final void Function(String operation, Map<String, int> durations)? onTiming;
  final _reads = <String, Future<Map<String, dynamic>>>{};

  static const readActions = {
    'getAdminStatus',
    'getSocialGraph',
    'getPublicProfile',
    'queryPublicProfiles',
    'searchPublicProfiles',
    'getDailyRewardStatus',
    'getMatchSnapshot',
  };

  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> data = const {},
    Duration? timeout,
  }) async {
    final session = sessionKey();
    if (session == null) {
      throw const SupabaseBackendException('unauthenticated');
    }
    final limit =
        timeout ?? Duration(seconds: readActions.contains(action) ? 12 : 20);
    // Take an immutable wire snapshot before token acquisition or deduplication.
    final body = jsonEncode({...data, 'action': action});
    final key = jsonEncode([session.toString(), body, limit.inMicroseconds]);
    Future<Map<String, dynamic>>? pending = readActions.contains(action)
        ? _reads[key]
        : null;
    if (pending == null) {
      pending = _request(action, body, session, limit).timeout(limit);
      if (readActions.contains(action)) _reads[key] = pending;
    }
    try {
      final result = await pending;
      if (sessionKey() != session) {
        throw const SupabaseBackendException('unauthenticated');
      }
      // Callers must not share mutable snapshot maps through an in-flight read.
      return jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
    } finally {
      if (identical(_reads[key], pending)) _reads.remove(key);
    }
  }

  Future<Map<String, dynamic>> _request(
    String action,
    String body,
    Object session,
    Duration limit,
  ) async {
    final total = Stopwatch()..start();
    final durations = <String, int>{};
    try {
      final bearer = await token();
      durations['token_ms'] = total.elapsedMilliseconds;
      if (sessionKey() != session || bearer == null || bearer.isEmpty) {
        throw const SupabaseBackendException('unauthenticated');
      }
      // A token completing after the deadline must not start a late mutation.
      if (total.elapsed >= limit) throw TimeoutException('backend deadline');
      final network = Stopwatch()..start();
      final response = await client.post(
        endpoint,
        headers: {
          'Authorization': 'Bearer $bearer',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      durations['http_ms'] = network.elapsedMilliseconds;
      if (sessionKey() != session) {
        throw const SupabaseBackendException('unauthenticated');
      }
      Map<String, dynamic> result;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        result = decoded;
      } on FormatException {
        throw const SupabaseBackendException('backend_unavailable');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SupabaseBackendException(
          result['error'] is String
              ? result['error'] as String
              : 'backend_unavailable',
          details: result,
        );
      }
      return result;
    } finally {
      durations['total_ms'] = total.elapsedMilliseconds;
      // Operation is a static caller name; never include body, UID or token.
      onTiming?.call(action, durations);
    }
  }
}
