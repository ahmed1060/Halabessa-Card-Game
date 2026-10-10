import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'backend_transport.dart';
export 'backend_transport.dart' show SupabaseBackendException;

/// Calls the private Supabase Edge Function using the current Firebase ID
/// token. The Supabase publishable key is intentionally not used here: all
/// game data remains server-only behind the function's Firebase JWT checks.
class SupabaseBackendService {
  static final http.Client _client = http.Client();
  static int _sessionGeneration = 0;
  static bool _watchingSession = false;
  static String? _sessionUid;

  static Object? _sessionKey() {
    final auth = FirebaseAuth.instance;
    if (!_watchingSession) {
      _watchingSession = true;
      _sessionUid = auth.currentUser?.uid;
      // One application-lifetime subscription. Logout/login of the same UID
      // is a new epoch; late responses cannot repopulate the new session.
      auth.authStateChanges().listen((user) {
        if (_sessionUid != user?.uid) {
          _sessionUid = user?.uid;
          _sessionGeneration++;
        }
      });
    }
    final uid = auth.currentUser?.uid;
    if (uid != _sessionUid) {
      _sessionUid = uid;
      _sessionGeneration++;
    }
    return uid == null ? null : '$uid:$_sessionGeneration';
  }

  static final Uri _endpoint = Uri.parse(
    'https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api',
  );
  static final _transport = BackendTransport(
    endpoint: _endpoint,
    client: _client,
    sessionKey: _sessionKey,
    token: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
    // Measured authenticated London reads were faster than automatic routing.
    // Empty HALABESSA_READ_REGION restores automatic routing at build time.
    preferredReadRegion: const String.fromEnvironment(
      'HALABESSA_READ_REGION',
      defaultValue: 'eu-west-2',
    ),
    // Authenticated command + continuous-delivery QA passed in London.
    // Empty HALABESSA_COMMAND_REGION restores automatic routing at build time.
    // Commands retain same-ID recovery in the match service, not blind retries.
    preferredCommandRegion: const String.fromEnvironment(
      'HALABESSA_COMMAND_REGION',
      defaultValue: 'eu-west-2',
    ),
    onTiming: (operation, durations) {
      if (!kReleaseMode) debugPrint('backend timing $operation $durations');
    },
  );

  static Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> data = const {},
    Duration? timeout,
  }) => _transport.call(action, data: data, timeout: timeout);

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
      timeout: const Duration(seconds: 40),
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
