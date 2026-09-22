import 'dart:convert';
import 'dart:typed_data';

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

  /// Uploads a release asset through the trusted Edge API. The Supabase
  /// service-role credential never leaves the backend.
  static Future<String> uploadAsset({
    required String kind,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    String? assetKey,
  }) async {
    if (bytes.isEmpty || bytes.lengthInBytes > 4 * 1024 * 1024) {
      throw const SupabaseBackendException('file_too_large');
    }
    final response = await call(
      'uploadAsset',
      data: {
        'kind': kind,
        'fileName': fileName,
        'contentType': contentType,
        'base64': base64Encode(bytes),
        if (assetKey != null) 'assetKey': assetKey,
      },
    );
    final publicUrl = response['publicUrl'];
    if (publicUrl is! String || publicUrl.isEmpty) {
      throw const SupabaseBackendException('asset_upload_failed');
    }
    return publicUrl;
  }
}
