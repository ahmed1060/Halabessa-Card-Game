import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';

enum AgeEligibility { unknown, eligible, blocked }

bool isAtLeast13(DateTime birthDate, DateTime today) {
  if (birthDate.isAfter(today)) return false;
  final years = today.year - birthDate.year;
  return years > 13 ||
      (years == 13 &&
          (today.month > birthDate.month ||
              (today.month == birthDate.month && today.day >= birthDate.day)));
}

class AgeEligibilityNotifier extends StateNotifier<AgeEligibility> {
  final SharedPreferences preferences;
  bool _submitting = false;
  static const key = 'age_eligibility_13_v1';
  AgeEligibilityNotifier(this.preferences)
    : super(switch (preferences.getString(key)) {
        'eligible' => AgeEligibility.eligible,
        'blocked' => AgeEligibility.blocked,
        _ => AgeEligibility.unknown,
      });
  Future<void> submit(DateTime birthDate, {DateTime? today}) async {
    if (state != AgeEligibility.unknown || _submitting) return;
    _submitting = true;
    final next = isAtLeast13(birthDate, today ?? DateTime.now())
        ? AgeEligibility.eligible
        : AgeEligibility.blocked;
    // The date is used in memory only. Store eligibility, not a birth date.
    try {
      if (!await preferences.setString(key, next.name)) {
        throw StateError('age_gate_save_failed');
      }
      state = next;
    } finally {
      _submitting = false;
    }
  }
}

final ageEligibilityProvider =
    StateNotifierProvider<AgeEligibilityNotifier, AgeEligibility>(
      (ref) => AgeEligibilityNotifier(ref.watch(sharedPreferencesProvider)),
    );
