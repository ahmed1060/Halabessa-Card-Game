import 'package:halabessa/core/services/supabase_backend_service.dart';

/// The room service accepts exactly three ASCII letters and five digits.
/// Normalize pasted lowercase codes before sending them to the server.
String normalizeRoomCode(String value) => value.trim().toUpperCase();

bool isValidRoomCode(String value) =>
    RegExp(r'^[A-Z]{3}[0-9]{5}$').hasMatch(normalizeRoomCode(value));

String joinRoomErrorKey(Object error) {
  final code = error is SupabaseBackendException ? error.code : '';
  return switch (code) {
    'invalid_room_id' => 'room_code_format',
    'room_not_found' => 'room_join_not_found',
    'room_full' => 'error_room_full',
    'room_not_joinable' => 'room_join_closed',
    'room_changed_retry' => 'room_join_retry',
    'unauthenticated' => 'room_sign_in_required',
    _ => 'error_service_unavailable',
  };
}

String createRoomErrorKey(Object error) {
  final code = error is SupabaseBackendException ? error.code : '';
  return code == 'unauthenticated'
      ? 'room_sign_in_required' : 'room_create_failed';
}
