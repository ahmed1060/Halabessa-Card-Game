import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class SupabaseBackendException implements Exception {
  final String code;
  const SupabaseBackendException(this.code);
  @override
  String toString() => code;
}

/// Calls the private Supabase Edge Function using the current Firebase ID
/// token. The Supabase publishable key is intentionally not used here: all
/// game data remains server-only behind the function's Firebase JWT checks.
class SupabaseBackendService {
  static final Uri _endpoint = Uri.parse(
    'https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api',
  );

  static Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> data = const {},
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) throw const SupabaseBackendException('unauthenticated');
    final response = await http.post(
      _endpoint,
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'action': action, ...data}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseBackendException(body['error'] as String? ?? 'backend_unavailable');
    }
    return body;
  }
}
