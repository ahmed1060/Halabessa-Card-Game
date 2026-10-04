import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Retry uncertain transport delivery once with the SAME immutable intent/ID.
/// Version/validation/auth failures are decisions, not transport retries.
Future<Map<String, dynamic>> sendIdempotentMatchRequest(
  Map<String, dynamic> intent,
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) send,
) async {
  final encoded = jsonEncode(intent);
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      return await send(Map<String, dynamic>.from(jsonDecode(encoded) as Map));
    } on TimeoutException {
      if (attempt == 1) rethrow;
    } on http.ClientException {
      if (attempt == 1) rethrow;
    }
  }
  throw StateError('unreachable');
}
