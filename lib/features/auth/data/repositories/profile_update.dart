/// Only the editable profile fields are written. Never round-trip game stats,
/// server-owned social fields, or admin mirrors through a profile form.
Map<String, dynamic> profileUpdate({
  required Map<String, dynamic> current,
  String? displayName,
  String? username,
  String? avatarUrl,
  bool canRenameWithoutTicket = false,
}) {
  final update = <String, dynamic>{};
  if (displayName != null) update['displayName'] = displayName;
  if (avatarUrl != null) update['avatarUrl'] = avatarUrl;
  if (username != null) {
    final normalized = username.trim();
    if (normalized.length < 3 || normalized.length > 20 ||
        !RegExp(r'^[a-zA-Z0-9_\u0600-\u06FF]+$').hasMatch(normalized)) {
      throw StateError('invalid_username');
    }
    final old = current['username'] as String?;
    if (old != null && old.isNotEmpty && normalized != old && !canRenameWithoutTicket) {
      final inventory = Map<String, dynamic>.from(current['inventory'] as Map? ?? {});
      final tickets = (inventory['username_change_ticket'] as num?)?.toInt() ?? 0;
      if (tickets <= 0) throw StateError('username_ticket_required');
      inventory['username_change_ticket'] = tickets - 1;
      update['inventory'] = inventory;
    }
    update['username'] = normalized;
  }
  if (username != null || displayName != null) {
    final savedUsername = username?.trim() ?? current['username'] as String?;
    update['searchName'] = (savedUsername != null && savedUsername.isNotEmpty
        ? savedUsername : displayName ?? current['displayName'] ?? '').toString().toLowerCase();
  }
  return update;
}
