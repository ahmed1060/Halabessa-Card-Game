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
    this.preferredReadRegion,
    this.preferredCommandRegion,
    this.regionalReadTimeout = const Duration(seconds: 4),
  });

  final Uri endpoint;
  final http.Client client;
  final Object? Function() sessionKey;
  final Future<String?> Function() token;
  final void Function(String operation, Map<String, int> durations)? onTiming;
  final String? preferredReadRegion;

  /// Optional command route. Never fails over or repeats an ambiguous write.
  final String? preferredCommandRegion;
  final Duration regionalReadTimeout;
  final _reads = <String, Future<Map<String, dynamic>>>{};
  DateTime? _commandRegionUnavailableUntil;

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
      Future<http.Response> send({String? region, Duration? attemptLimit}) {
        // Recheck before every attempt: a late token/failed route must not
        // launch requests after logout or after the original call deadline.
        if (sessionKey() != session) {
          throw const SupabaseBackendException('unauthenticated');
        }
        final remaining = limit - total.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('backend deadline');
        }
        final budget = attemptLimit != null && attemptLimit < remaining
            ? attemptLimit
            : remaining;
        return client
            .post(
              endpoint,
              headers: {
                'Authorization': 'Bearer $bearer',
                'Content-Type': 'application/json',
                if (region != null) 'x-region': region,
              },
              body: body,
            )
            .timeout(budget);
      }

      // Only these ordinary reads may fail over. Purchases, deletion,
      // rewards, joins and commands are never retried by this transport.
      final isRead = readActions.contains(action);
      final commandRouteAvailable =
          _commandRegionUnavailableUntil == null ||
          DateTime.now().isAfter(_commandRegionUnavailableUntil!);
      final region = isRead
          ? preferredReadRegion
          : action == 'submitMatchCommand' && commandRouteAvailable
          ? preferredCommandRegion
          : null;
      http.Response response;
      if (!isRead || region == null || region.isEmpty) {
        final routedCommand = !isRead && region?.isNotEmpty == true;
        void coolDownCommandRoute() {
          if (routedCommand) {
            _commandRegionUnavailableUntil = DateTime.now().add(
              const Duration(minutes: 1),
            );
          }
        }

        try {
          response = await send(
            region: region?.isNotEmpty == true ? region : null,
          );
          if ([502, 503, 504].contains(response.statusCode)) {
            coolDownCommandRoute();
          }
        } on http.ClientException {
          coolDownCommandRoute();
          rethrow;
        } on TimeoutException {
          coolDownCommandRoute();
          rethrow;
        }
        // Do NOT repeat this request. A later same-ID recovery/new call may
        // use automatic routing during cooldown, under the caller's existing
        // authorization, version and command-ID checks.
      } else {
        http.Response? regional;
        try {
          regional = await send(
            region: region,
            attemptLimit: regionalReadTimeout,
          );
        } on http.ClientException {
          /* Safe read-only fallback below. */
        } on TimeoutException {
          /* Original total deadline still applies. */
        }
        if (regional == null || [502, 503, 504].contains(regional.statusCode)) {
          durations['route_fallback'] = 1;
          response = await send();
        } else {
          response = regional;
        }
      }
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
